require "set"

module Parse
  module ReconciliationEnqueuer
    module_function

    def enqueue(report_file:, day_currency_map:)
      return if day_currency_map.blank?

      scope = Sources::ScopeKey.build(report_file.account_code, report_file.account_id)
      seen = Set.new

      day_currency_map.each do |day, currencies|
        next if day.blank?

        normalized_currencies = currencies.to_a.compact
        normalized_currencies << report_file.currency if normalized_currencies.empty? && report_file.currency.present?
        normalized_currencies = normalized_currencies.compact.uniq
        normalized_currencies = [report_file.currency].compact if normalized_currencies.empty?

        normalized_currencies.each do |currency|
          key = [day, currency]
          next if seen.include?(key)

          seen << key
          ReconcileDayJob.perform_later(account_scope: scope, date: day, currency: currency)
        end
      end
    end
  end
end
