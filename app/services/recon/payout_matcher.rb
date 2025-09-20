module Recon
  class PayoutMatcher
    # bank_lines: array of {date:, currency:, amount_cents:, ref:}
    def initialize(account_scope:, bank_lines:, date: nil, currency: nil)
      @scope       = account_scope
      @bank_lines  = Array(bank_lines)
      @date_filter = date
      @currency_filter = currency
    end

    def call
      adyen_payouts = Sources::Payouts.for(@scope, date: @date_filter, currency: @currency_filter)

      scope_matches = PayoutMatch.where(account_scope: @scope)
      scope_matches = scope_matches.where(payout_date: @date_filter) if @date_filter
      scope_matches = scope_matches.where(currency: @currency_filter) if @currency_filter
      scope_matches.delete_all

      adyen_payouts.each do |p|
        match = @bank_lines.find { |b| b[:currency] == p[:currency] && b[:amount_cents].to_i == p[:amount_cents].to_i && (b[:date] - p[:date]).abs <= 2 }
        status, details = if match
                            [:matched, { bank_ref: match[:ref], bank_amount_cents: match[:amount_cents] }]
                          else
                            [:unmatched, {}]
                          end
        payout_currency = p[:currency] || @currency_filter

        PayoutMatch.create!(
          account_scope: @scope, payout_date: p[:date], currency: payout_currency,
          adyen_payout_id: p[:id], adyen_amount_cents: p[:amount_cents],
          bank_ref: details[:bank_ref], bank_amount_cents: details[:bank_amount_cents],
          status:, details: details.except(:bank_amount_cents)
        )
      end
    end
  end
end