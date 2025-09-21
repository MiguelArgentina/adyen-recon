# frozen_string_literal: true
module Sources
  class Statement
    C = Config

    def self.total_for(scope, date, currency)
      return 0 unless C::StatementLine

      capture_scope(scope, date, currency).sum(C::SL_AMOUNT).to_i
    end

    def self.capture_scope(scope, date, currency)
      rf_kind = ReportFile.kinds[C::KIND_STATEMENT] # integer enum

      account_code, account_holder = Sources::ScopeKey.parse(scope)

      base = C::StatementLine
               .joins("INNER JOIN report_files rf ON rf.id = statement_lines.#{C::SL_FILE_ID}")
               .where("rf.#{C::RF_KIND} = ?", rf_kind)

      base = if account_code.nil? && account_holder.nil?
               base.where("COALESCE(rf.#{C::RF_SCOPE}, '') = ''")
                   .where("COALESCE(rf.account_id, '') = ''")
             else
               scoped = base
               scoped = scoped.where("rf.#{C::RF_SCOPE} = ?", account_code) if account_code
               scoped = scoped.where("rf.account_id = ?", account_holder) if account_holder
               scoped
             end

      base
        .where("statement_lines.#{C::SL_BOOK_DATE} = ?", date)
        .where(<<~SQL, currency, currency)
          (statement_lines.#{C::SL_CURRENCY} = ?
            OR (statement_lines.#{C::SL_CURRENCY} IS NULL OR statement_lines.#{C::SL_CURRENCY} = '')
               AND rf.#{C::RF_CURRENCY} = ?)
        SQL
        .where("LOWER(statement_lines.#{C::SL_CATEGORY}) IN (?)", %w[payment platformpayment])
        .where("LOWER(statement_lines.#{C::SL_TYPE}) = 'capture'")
    end
  end
end
