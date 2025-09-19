# app/services/parse/accounting.rb
require "csv"
require "set"

module Parse
  class Accounting
    ROW_ERROR_ABORT_THRESHOLD = 50

    # header aliases (normalized to downcase + keep letters/digits/dots/spaces removed)
    OCC_DATE_KEYS  = %w[valuedate value_date eventdate date]
    BOOK_DATE_KEYS = %w[accountingdate bookingdate bookdate book_date date]
    CAT_KEYS       = %w[category]
    TYPE_KEYS      = %w[type]
    SUBCAT_KEYS    = %w[subtype subcategory]
    STATUS_KEYS    = %w[status]
    AMOUNT_KEYS    = %w[amount amount.value]
    CURR_KEYS      = %w[currency amount.currency paymentcurrency]
    REF_KEYS       = %w[reference]
    DESC_KEYS      = %w[description]
    PSPPAYREF_KEYS = %w[psppaymentpspreference pspreference psp_payment_psp_reference]
    PSPMODREF_KEYS = %w[pspmodificationpspreference pspmodificationpspreference]
    MERCHREF_KEYS  = %w[psppaymentmerchantreference]
    TRANSFER_KEYS  = %w[transferid transfer_id]
    PAYOUT_KEYS    = %w[payoutid payout_id]

    # 🔑 Balance Account (this was missing)
    # include both id/code and “beneficiary …” variants seen in Accounting exports
    BA_ID_KEYS   = %w[balanceaccountid balanceaccount beneficiarybalanceaccount counterpartybalanceaccountid counterpartybalanceaccount]
    BA_CODE_KEYS = %w[balanceaccountcode balanceaccount beneficiarybalanceaccount]

    def self.call(report_file)
      raise "No attached file" unless report_file.file.attached?

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      io = report_file.file.download
      created = 0
      skipped = 0
      row_errors = []
      currencies = Set.new
      touched_days = Set.new

      # ✅ Idempotency per file
      AccountingEntry.where(report_file_id: report_file.id).delete_all

      csv = CSV.new(io, headers: true)

      ActiveRecord::Base.transaction do
        csv.each_with_index do |row, i|
          begin
            norm = normalize_hash(row.to_h)

            occurred_on = safe_date(pick(norm, *OCC_DATE_KEYS))
            book_date   = safe_date(pick(norm, *BOOK_DATE_KEYS)) || occurred_on || report_file.reported_on
            unless book_date
              skipped += 1
              next
            end
            touched_days << book_date

            amount   = money_to_minor(pick(norm, *AMOUNT_KEYS))
            currency = pick(norm, *CURR_KEYS)
            currencies << currency if currency

            # 💳 Balance account: prefer explicit id/code; fallback to code; if still missing, synthesize stable key
            ba_id   = pick(norm, *BA_ID_KEYS)
            ba_code = pick(norm, *BA_CODE_KEYS)
            if ba_id.blank? && ba_code.present?
              ba_id = ba_code
            elsif ba_id.blank? && ba_code.blank?
              ba_id = ba_code = "BA|#{currency || 'UNK'}"
            end

            AccountingEntry.create!(
              report_file_id: report_file.id,
              line_no: i + 1,
              occurred_on: occurred_on || book_date,
              book_date: book_date,
              direction: pick(norm, 'direction'),
              category:  pick(norm, *CAT_KEYS)&.downcase,
              type:      pick(norm, *TYPE_KEYS)&.downcase,      # e.g. "bankTransfer" -> "banktransfer"
              subcategory: pick(norm, *SUBCAT_KEYS)&.downcase,
              status:    pick(norm, *STATUS_KEYS) || 'booked',
              amount_minor: amount,
              currency: currency,

              balance_account_id:   ba_id,
              balance_account_code: ba_code,

              psp_reference: pick(norm, *PSPPAYREF_KEYS),
              transfer_id:   pick(norm, *TRANSFER_KEYS),
              payout_id:     pick(norm, *PAYOUT_KEYS),
              reference:     pick(norm, *REF_KEYS),
              description:   pick(norm, *DESC_KEYS)
            )
            created += 1

          rescue => e
            row_errors << "row=#{i+1}: #{e.class}: #{e.message}"
            skipped += 1
            raise ActiveRecord::Rollback if row_errors.size >= ROW_ERROR_ABORT_THRESHOLD
          end
        end
      end

      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
      status_symbol = (row_errors.empty? && skipped.zero?) ? :parsed_ok : :parsed_with_errors

      report_file.update!(
        status: status_symbol,
        error: nil,
        settings: (report_file.settings.is_a?(Hash) ? report_file.settings : {}).merge(
          'currencies' => currencies.to_a,
          'rows_created' => created,
          'rows_skipped' => skipped,
          'row_errors_sample' => row_errors.first(10),
          'row_errors_count' => row_errors.size,
          'elapsed_ms' => elapsed_ms
        )
      )

      # best-effort summaries refresh
      touched_days.each do |day|
        Summarize::BuildDailySummaries.call(day: day) rescue Rails.logger.warn("[Parse::Accounting] summary rebuild failed day=#{day}")
      end

    rescue => e
      report_file.update_columns(status: ReportFile.statuses[:failed], error: e.message) rescue nil
      raise
    end

    # --- helpers ---
    def self.normalize_key(k) k.to_s.strip.downcase.gsub(/[^a-z0-9\.]/,'') end
    def self.normalize_hash(h) h.each_with_object({}) { |(k,v),acc| acc[normalize_key(k)] = v } end
    def self.pick(hash, *keys) keys.each { |k| v = hash[k]; return v unless v.nil? || v.to_s.strip.empty? }; nil end
    def self.safe_date(v) return nil if v.nil? || v.to_s.strip.empty?; Date.parse(v.to_s) rescue nil end
    def self.money_to_minor(v) return nil if v.nil? || v.to_s.strip.empty?; (Float(v.to_s.gsub(/[,]/,'')) * 100).round rescue nil end
  end
end
