# app/services/sources/accounting.rb
# frozen_string_literal: true
module Sources
  class Accounting
    C = Config

    def self.total_for(scope, date, currency)
      rf_kind = ReportFile.kinds[C::KIND_ACCOUNTING]

      C::AccountingEntry
        .joins("INNER JOIN report_files rf ON rf.id = accounting_entries.#{C::AE_FILE_ID}")
        .where("rf.#{C::RF_KIND} = ?", rf_kind)
        .yield_self do |rel|
          account_code, account_holder = Sources::ScopeKey.parse(scope)
          if account_code.nil? && account_holder.nil?
            rel.where("COALESCE(rf.#{C::RF_SCOPE}, '') = ''").where("COALESCE(rf.account_id, '') = ''")
          else
            scoped = rel
            scoped = scoped.where("rf.#{C::RF_SCOPE} = ?", account_code) if account_code
            scoped = scoped.where("rf.account_id = ?", account_holder) if account_holder
            scoped
          end
        end
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
