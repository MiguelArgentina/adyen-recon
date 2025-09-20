# app/services/parse/statement.rb
require "csv"
require "set"

module Parse
  class Statement
    ROW_ERROR_ABORT_THRESHOLD = 50

    # header variants (all normalized to downcased + stripped)
    OCC_DATE_KEYS  = %w[valuedate value_date bookingdate eventdate date]
    BOOK_DATE_KEYS = %w[valuedate value_date bookingdate bookdate book_date date]
    CAT_KEYS       = %w[category]
    TYPE_KEYS      = %w[type]
    STATUS_KEYS    = %w[status]
    AMOUNT_KEYS    = %w[amount amount.value]
    CURR_KEYS      = %w[currency amount.currency]
    BAL_BEF_KEYS   = %w[startingbalance starting_balance startbalance]
    BAL_AFT_KEYS   = %w[endingbalance ending_balance endbalance]
    BA_ID_KEYS     = %w[balanceaccountid balanceaccount balance accountid account ledgeraccountid ledgeraccount]
    BA_CODE_KEYS   = %w[balanceaccountcode balanceaccount balance accountcode account ledgeraccountcode ledgeraccount]
    REF_KEYS       = %w[reference]
    TRX_ID_KEYS    = %w[transferid transfer_id]
    PAYOUT_ID_KEYS = %w[payoutid payout_id]
    DESC_KEYS      = %w[description]
    CP_NAME_KEYS   = %w[counterpartyname counterparty counter_party]

    RowAbort = Class.new(StandardError)
    private_constant :RowAbort

    def self.call(report_file)
      raise "No attached file" unless report_file.file.attached?

      start_time    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raw_csv       = report_file.file.download
      currencies    = Set.new
      skipped       = 0
      row_errors    = []
      distinct_days = Set.new
      day_currency_map = Hash.new { |h, k| h[k] = Set.new }
      rows_buffer   = []
      created       = 0
      aborted       = false

      begin
        ActiveRecord::Base.transaction do
          report_file.lock!

          csv = CSV.new(raw_csv, headers: true)

          csv.each_with_index do |row, i|
            begin
              norm = normalize_hash(row.to_h)

              occurred_on = safe_date(pick(norm, *OCC_DATE_KEYS))
              book_date   = safe_date(pick(norm, *BOOK_DATE_KEYS)) || occurred_on || report_file.reported_on
              unless book_date
                skipped += 1
                next
              end

              amount   = money_to_minor(pick(norm, *AMOUNT_KEYS))
              currency = pick(norm, *CURR_KEYS)

              ba_id   = pick(norm, *BA_ID_KEYS)
              ba_code = pick(norm, *BA_CODE_KEYS)
              if ba_id.blank? && ba_code.present?
                ba_id = ba_code
              elsif ba_id.blank? && ba_code.blank?
                ba_id = ba_code = "BA|#{currency || 'UNK'}"
              end

              attrs = {
                report_file_id:       report_file.id,
                line_no:              i + 1,
                occurred_on:          occurred_on || book_date,
                book_date:            book_date,
                category:             pick(norm, *CAT_KEYS)&.downcase,
                type:                 pick(norm, *TYPE_KEYS)&.downcase,
                status:               pick(norm, *STATUS_KEYS) || 'booked',
                amount_minor:         amount,
                currency:             currency,
                balance_before_minor: money_to_minor(pick(norm, *BAL_BEF_KEYS)),
                balance_after_minor:  money_to_minor(pick(norm, *BAL_AFT_KEYS)),
                balance_account_id:   ba_id,
                balance_account_code: ba_code,
                reference:            pick(norm, *REF_KEYS),
                transfer_id:          pick(norm, *TRX_ID_KEYS),
                payout_id:            pick(norm, *PAYOUT_ID_KEYS),
                description:          pick(norm, *DESC_KEYS),
                counterparty:         pick(norm, *CP_NAME_KEYS)
              }

              rows_buffer << attrs
              distinct_days << book_date
              day_currency_map[book_date] << currency
              currencies << currency if currency.present?

            rescue => e
              row_errors << "row=#{i + 1}: #{e.class}: #{e.message}"
              skipped += 1
              raise RowAbort if row_errors.size >= ROW_ERROR_ABORT_THRESHOLD
            end
          end

          StatementLine.where(report_file_id: report_file.id).delete_all
          purge_overlapping_statement_lines(report_file, day_currency_map)
          rows_buffer.each { |attrs| StatementLine.create!(attrs) }
        end

        created = rows_buffer.size
      rescue RowAbort
        aborted = true
        created = 0
        rows_buffer.clear
        distinct_days.clear
        day_currency_map = Hash.new { |h, k| h[k] = Set.new }
        currencies.clear
      end

      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(1)
      status_symbol = (row_errors.empty? && skipped.zero?) ? :parsed_ok : :parsed_with_errors

      settings_payload = (report_file.respond_to?(:settings) && report_file.settings.is_a?(Hash) ? report_file.settings : {}).merge(
        'currencies'        => currencies.to_a,
        'rows_created'      => created,
        'rows_skipped'      => skipped,
        'row_errors_sample' => row_errors.first(10),
        'row_errors_count'  => row_errors.size,
        'elapsed_ms'        => elapsed_ms
      )
      report_file.update!(status: status_symbol, error: nil, settings: settings_payload)

      unless aborted
        distinct_days.each do |day|
          begin
            Summarize::BuildDailySummaries.call(day: day)
          rescue => e
            Rails.logger.error("[Parse::Statement] summary rebuild failed day=#{day} err=#{e.class}: #{e.message}")
          end
        end
      end

    rescue => e
      report_file.update_columns(status: ReportFile.statuses[:failed], error: e.message) rescue nil
      raise
    end

    private_class_method def self.purge_overlapping_statement_lines(report_file, day_currency_map)
      return if day_currency_map.empty?

      rf_scope = {
        account_code: report_file.account_code,
        account_id: report_file.account_id,
        adyen_credential_id: report_file.adyen_credential_id,
        kind: ReportFile.kinds[:statement]
      }

      base = StatementLine.joins(:report_file)
                          .where(report_files: rf_scope)
                          .where.not(statement_lines: { report_file_id: report_file.id })

      day_currency_map.each do |day, currencies|
        scoped = base.where(statement_lines: { book_date: day })
        values = currencies.to_a
        non_nil = values.compact

        unless non_nil.empty?
          scoped.where(statement_lines: { currency: non_nil }).delete_all
        end

        if values.any?(&:nil?)
          scoped.where("statement_lines.currency IS NULL OR statement_lines.currency = ''").delete_all
        end
      end
    end

    # --- helpers ---
    def self.money_to_minor(val)
      return nil if val.nil? || val.to_s.strip.empty?

      (Float(val.to_s.gsub(/[,]/, "")) * 100).round
    rescue ArgumentError, TypeError
      nil
    end

    def self.safe_date(val)
      return nil if val.nil? || val.to_s.strip.empty?
      Date.parse(val.to_s) rescue nil
    end

    # normalize: downcase, keep letters/digits/dots (so "Amount.Value" => "amount.value")
    def self.normalize_key(k) k.to_s.strip.downcase.gsub(/[^a-z0-9\.]/,'') end
    def self.normalize_hash(h) h.each_with_object({}) { |(k,v), acc| acc[normalize_key(k)] = v } end
    def self.pick(hash, *keys)
      keys.each do |k|
        v = hash[k]
        return v unless v.nil? || v.to_s.strip.empty?
      end
      nil
    end
  end
end
