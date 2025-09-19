# frozen_string_literal: true
module Sources
  class Computed
    C = Config

    def self.total_for(scope, date, currency)
      rf_kind = ReportFile.kinds[C::KIND_ACCOUNTING]

      C::AccountingEntry
        .joins("INNER JOIN report_files rf ON rf.id = accounting_entries.#{C::AE_FILE_ID}")
        .where("rf.#{C::RF_KIND} = ?", rf_kind)
        .yield_self { |rel|
          if scope.nil?
            rel.where("rf.#{C::RF_SCOPE} IS NULL")
          else
            rel.where("rf.#{C::RF_SCOPE} = ?", scope)
          end
        }
        .where("accounting_entries.#{C::AE_BOOK_DATE} = ?", date)
        .where(<<~SQL, currency, currency)
          (accounting_entries.#{C::AE_CURRENCY} = ?
            OR (accounting_entries.#{C::AE_CURRENCY} IS NULL OR accounting_entries.#{C::AE_CURRENCY} = '')
               AND rf.#{C::RF_CURRENCY} = ?)
        SQL
        .where("LOWER(accounting_entries.#{C::AE_CATEGORY}) = 'platformpayment'")
        .where("LOWER(accounting_entries.#{C::AE_TYPE}) = 'capture'")
        .where.not("LOWER(accounting_entries.#{C::AE_TYPE}) IN ('banktransfer','internaltransfer')")
        .sum(C::AE_AMOUNT) || 0
    end
  end
end
