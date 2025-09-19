module Recon
  class PayoutMatcher
    # bank_lines: array of {date:, currency:, amount_cents:, ref:}
    def initialize(account_scope:, bank_lines:)
      @scope, @bank_lines = account_scope, bank_lines
    end

    def call
      adyen_payouts = Sources::Payouts.for(@scope) # [{id:, date:, currency:, amount_cents:}, ...]
      adyen_payouts.each do |p|
        match = @bank_lines.find { |b| b[:currency] == p[:currency] && b[:amount_cents].to_i == p[:amount_cents].to_i && (b[:date] - p[:date]).abs <= 2 }
        status, details = if match
                            [:matched, { bank_ref: match[:ref] }]
                          else
                            [:unmatched, {}]
                          end
        PayoutMatch.create!(
          account_scope: @scope, payout_date: p[:date], currency: p[:currency],
          adyen_payout_id: p[:id], adyen_amount_cents: p[:amount_cents],
          bank_ref: details[:bank_ref], bank_amount_cents: match&.dig(:amount_cents),
          status:, details:
        )
      end
    end
  end
end