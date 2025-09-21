# app/services/recon/build_daily.rb
module Recon
  class BuildDaily
    def initialize(account_scope:, date:, currency:)
      @scope_in = account_scope.presence # can be nil
      @date     = date
      @currency = currency
    end

    def call
      scopes = Array(@scope_in).map { |scope| scope.presence }.presence

      # If no explicit scope, derive from data; include nil as a scope
      if scopes.blank?
        scopes = []
        # Prefer actual line tables for the day (don’t over-filter by RF currency/kind)
        if Sources::Config::AccountingEntry
          scopes |= ReportFile
                      .joins("INNER JOIN accounting_entries ae ON ae.report_file_id = report_files.id")
                      .where(<<~SQL, @date)
                        COALESCE(
                          ae.#{Sources::Config::AE_BOOK_DATE},
                          ae.#{Sources::Config::AE_DATE},
                          report_files.#{Sources::Config::RF_REPORTED_ON}
                        ) = ?
                      SQL
                      .distinct
                      .pluck(Sources::Config::RF_SCOPE, "report_files.account_id")
                      .map { |code, account_id| Sources::ScopeKey.build(code, account_id) }
        end
        if Sources::Config::StatementLine
          scopes |= ReportFile
                      .joins("INNER JOIN statement_lines sl ON sl.report_file_id = report_files.id")
                      .where(<<~SQL, @date)
                        COALESCE(
                          sl.#{Sources::Config::SL_BOOK_DATE},
                          sl.#{Sources::Config::SL_DATE},
                          report_files.#{Sources::Config::RF_REPORTED_ON}
                        ) = ?
                      SQL
                      .distinct
                      .pluck(Sources::Config::RF_SCOPE, "report_files.account_id")
                      .map { |code, account_id| Sources::ScopeKey.build(code, account_id) }
        end
        scopes = scopes.map { |scope| scope.presence }.uniq
        scopes.unshift(nil) unless scopes.include?(nil)  # ← ensure we compute the nil scope
      end

      last = nil
      ReconciliationDay.transaction do
        scopes.each do |scope|
          normalized_scope = scope.presence
          relation = ReconciliationDay.lock.where(account_scope: normalized_scope, date: @date, currency: @currency)
          day = relation.order(updated_at: :desc).first

          if day
            relation.where.not(id: day.id).destroy_all
          else
            day = ReconciliationDay.new(account_scope: normalized_scope, date: @date, currency: @currency)
          end

          day.statement_total_cents  = Sources::Statement.total_for(normalized_scope, @date, @currency)
          day.accounting_total_cents = Sources::Accounting.total_for(normalized_scope, @date, @currency)
          day.computed_total_cents   = Sources::Computed.total_for(normalized_scope, @date, @currency)
          day.status = :pending
          day.save!

          Recon::ExplainVariance.new(day).call
          day.compute_status!
          last = day
        end
      end
      last
    end
  end
end
