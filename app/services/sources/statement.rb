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

      C::StatementLine
        .joins("INNER JOIN report_files rf ON rf.id = statement_lines.#{C::SL_FILE_ID}")
        .where("rf.#{C::RF_KIND} = ?", rf_kind)
        .yield_self { |rel|
          if scope.nil?
            rel.where("rf.#{C::RF_SCOPE} IS NULL")
          else
            rel.where("rf.#{C::RF_SCOPE} = ?", scope)
          end
        }
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
