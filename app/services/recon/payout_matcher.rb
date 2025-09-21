module Recon
  class PayoutMatcher
    # bank_lines: array of {date:, currency:, amount_cents:, ref:}
    def initialize(account_scope:, bank_lines:, date: nil, currency: nil)
      @scope       = account_scope.presence
      @scope_account_code, @scope_account_holder = Sources::ScopeKey.parse(@scope)
      @bank_lines  = Array(bank_lines).map { |line| normalize_bank_line(line) }.compact
      @date_filter = date
      @currency_filter = normalize_currency(currency)
    end

    def call
      adyen_payouts = Sources::Payouts.for(@scope, date: @date_filter, currency: @currency_filter)

      scope_matches = PayoutMatch.where(account_scope: @scope)
      scope_matches = scope_matches.where(payout_date: @date_filter) if @date_filter
      scope_matches = scope_matches.where(currency: @currency_filter) if @currency_filter
      scope_matches.delete_all

      adyen_payouts.each do |p|
        payout_currency = normalize_currency(p[:currency]) || @currency_filter
        capture_result = capture_transactions_until(payout_date: p[:date], currency: payout_currency)
        transactions = capture_result[:transactions]

        transactions_total = transactions.sum { |tx| tx[:amount_cents].to_i }
        payout_amount = p[:amount_cents].to_i.abs

        match = @bank_lines.find do |b|
          b[:currency] == payout_currency &&
            b[:amount_cents].to_i == p[:amount_cents].to_i &&
            (b[:date] - p[:date]).abs <= 2
        end

        details = {}
        details[:bank_ref] = match[:ref] if match
        details[:transactions] = transactions
        details[:transactions_total_cents] = transactions_total
        details[:transactions_period_start] = capture_result[:period_start]&.to_s

        status = if payout_amount == transactions_total
                   :matched
                 elsif transactions_total.zero?
                   :unmatched
                 else
                   :partial
                 end

        PayoutMatch.create!(
          account_scope: @scope,
          payout_date: p[:date],
          currency: payout_currency,
          adyen_payout_id: p[:id],
          adyen_amount_cents: p[:amount_cents],
          bank_ref: match&.[](:ref),
          bank_amount_cents: match&.[](:amount_cents),
          status:,
          details: details
        )
      end
    end

    private

    def normalize_currency(value)
      str = value.to_s.strip
      return nil if str.empty?

      str.upcase
    end

    def normalize_bank_line(line)
      hash = line.respond_to?(:to_h) ? line.to_h : line
      return nil unless hash.is_a?(Hash)

      hash = hash.symbolize_keys if hash.respond_to?(:symbolize_keys)
      hash[:currency] = normalize_currency(hash[:currency])
      hash
    end

    def capture_transactions_until(payout_date:, currency:)
      stmt_model = Sources::Config::StatementLine
      return { transactions: [], period_start: nil } unless stmt_model

      relation = stmt_model.joins("INNER JOIN report_files rf ON rf.id = statement_lines.#{Sources::Config::SL_FILE_ID}")
      relation = apply_scope_filter(relation, @scope_account_code, @scope_account_holder)

      relation = relation.where(<<~SQL, currency, currency)
        (statement_lines.#{Sources::Config::SL_CURRENCY} = ?
          OR (statement_lines.#{Sources::Config::SL_CURRENCY} IS NULL OR statement_lines.#{Sources::Config::SL_CURRENCY} = '')
             AND rf.#{Sources::Config::RF_CURRENCY} = ?)
      SQL

      relation = relation.where("LOWER(statement_lines.#{Sources::Config::SL_CATEGORY}) IN (?)", %w[payment platformpayment])
                         .where("LOWER(statement_lines.#{Sources::Config::SL_TYPE}) = 'capture'")

      previous_date = previous_payout_date(payout_date:, currency:)

      relation = relation.where("statement_lines.#{Sources::Config::SL_BOOK_DATE} < ?", payout_date)
      relation = relation.where("statement_lines.#{Sources::Config::SL_BOOK_DATE} > ?", previous_date) if previous_date

      rows = relation.order("statement_lines.#{Sources::Config::SL_BOOK_DATE} ASC, statement_lines.line_no ASC")
                      .pluck(Sources::Config::SL_BOOK_DATE, "statement_lines.reference", Sources::Config::SL_AMOUNT)

      transactions = rows.map do |date, reference, amount|
        {
          value_date: date&.to_s,
          date: date&.to_s,
          reference: reference,
          amount_cents: amount.to_i
        }
      end

      { transactions:, period_start: previous_date }
    end

    def previous_payout_date(payout_date:, currency:)
      payout_model = Sources::Config::PayoutModel
      return nil unless payout_model

      relation = payout_model.left_joins(:source_report_file)
      relation = apply_scope_filter(relation, @scope_account_code, @scope_account_holder, table_alias: "report_files")

      relation = relation.where("COALESCE(payouts.currency, report_files.#{Sources::Config::RF_CURRENCY}) = ?", currency)
      relation = relation.where("payouts.booked_on < ?", payout_date)

      relation.order(booked_on: :desc).limit(1).pick(:booked_on)
    end

    def apply_scope_filter(relation, account_code, account_holder, table_alias: "rf")
      table = table_alias

      if account_code.nil? && account_holder.nil?
        relation
          .where("COALESCE(#{table}.#{Sources::Config::RF_SCOPE}, '') = ''")
          .where("COALESCE(#{table}.account_id, '') = ''")
      else
        scoped = relation
        scoped = scoped.where("#{table}.#{Sources::Config::RF_SCOPE} = ?", account_code) if account_code
        scoped = scoped.where("#{table}.account_id = ?", account_holder) if account_holder
        scoped
      end
    end
  end
end
