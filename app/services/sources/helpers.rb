# frozen_string_literal: true
module Sources
  module Helpers
    extend self

    def sum_cents(rel, column)
      rel.sum(column.to_sym).to_i
    end

    # Scope filter (optional). If scope is nil/blank, skip it.
    def scope_predicate(rf, scope)
      account_code, account_holder = ScopeKey.parse(scope)
      if account_code.nil? && account_holder.nil?
        scope_blank = rf[Config::RF_SCOPE].eq(nil).or(rf[Config::RF_SCOPE].eq(""))
        holder_blank = rf[:account_id].eq(nil).or(rf[:account_id].eq(""))
        scope_blank.and(holder_blank)
      else
        predicates = []
        predicates << rf[Config::RF_SCOPE].eq(account_code) if account_code
        predicates << rf[:account_id].eq(account_holder) if account_holder
        predicates.reduce { |acc, pred| acc.and(pred) } || Arel::Nodes::SqlLiteral.new("TRUE")
      end
    end

    # Prefer line date/currency, else fall back to report_file
    def date_match(lines_arel, line_date_col, rf_table, rf_date_col, date)
      ld = lines_arel[line_date_col]
      rd = rf_table[rf_date_col]
      ld.eq(date).or(ld.eq(nil).and(rd.eq(date)))
    end

    def currency_match(lines_arel, line_curr_col, rf_table, rf_curr_col, currency)
      lc = lines_arel[line_curr_col]
      rc = rf_table[rf_curr_col]
      # treat blank "" as nil for fallback
      lc.eq(currency).or(lc.eq(nil).or(lc.eq("")).and(rc.eq(currency)))
    end

    # Resolve ReportFile enum integer for given ruby value ("statement"/"accounting")
    def rf_kind_value(ruby_value)
      return nil unless Config::ReportFile
      kinds = Config::ReportFile.try(:kinds)
      kinds ? kinds[ruby_value] : ruby_value # if enums missing, fall back to raw compare
    end
  end
end
