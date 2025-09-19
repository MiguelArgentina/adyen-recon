# app/services/recon/build_daily.rb
module Recon
  class BuildDaily
    def initialize(account_scope:, date:, currency:)
      @scope_in = account_scope          # can be nil
      @date     = date
      @currency = currency
    end

    def call
      scopes = Array(@scope_in).presence

      # If no explicit scope, derive from data; include nil as a scope
      if scopes.blank?
        scopes = []
        # Prefer actual line tables for the day (don’t over-filter by RF currency/kind)
        if Sources::Config::AccountingEntry
          scopes |= ReportFile
                      .joins("INNER JOIN accounting_entries ae ON ae.report_file_id = report_files.id")
                      .where("ae.#{Sources::Config::AE_DATE} = ?", @date)
                      .distinct.pluck(Sources::Config::RF_SCOPE)
        end
        if Sources::Config::StatementLine
          scopes |= ReportFile
                      .joins("INNER JOIN statement_lines sl ON sl.report_file_id = report_files.id")
                      .where("sl.#{Sources::Config::SL_DATE} = ?", @date)
                      .distinct.pluck(Sources::Config::RF_SCOPE)
        end
        scopes = scopes.uniq
        scopes.unshift(nil) unless scopes.include?(nil)  # ← ensure we compute the nil scope
      end

      last = nil
      scopes.each do |scope|
        day = ReconciliationDay.lock.find_or_initialize_by(account_scope: scope, date: @date, currency: @currency)

        day.statement_total_cents  = Sources::Statement.total_for(scope, @date, @currency)
        day.accounting_total_cents = Sources::Accounting.total_for(scope, @date, @currency)
        day.computed_total_cents   = Sources::Computed.total_for(scope, @date, @currency)
        day.status = :pending
        day.save!

        Recon::ExplainVariance.new(day).call
        day.compute_status!
        last = day
      end
      last
    end
  end
end
