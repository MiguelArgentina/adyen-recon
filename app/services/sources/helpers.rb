# frozen_string_literal: true
module Sources
  module Helpers
    extend self

    def sum_cents(rel, column)
      rel.sum(column.to_sym).to_i
    end

    # Scope filter (optional). If scope is nil/blank, skip it.
    def scope_predicate(rf, scope)
      return Arel::Nodes::SqlLiteral.new("TRUE") if scope.blank?
      rf[Config::RF_SCOPE].eq(scope)
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
