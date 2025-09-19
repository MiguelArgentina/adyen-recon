module Recon
  class FeeIntel
    def initialize(account_scope:, date:, currency:)
      @scope, @date, @currency = account_scope, date, currency
    end

    def call
      fb = FeeBreakdown.find_or_initialize_by(account_scope: @scope, date: @date, currency: @currency)
      # Map your parsed Accounting/Statement lines into categories here
      fees = Sources::Fees.for(@scope, @date, @currency) # returns a hash with cents per category
      fb.assign_attributes(
        scheme_fees_cents:      fees[:scheme].to_i,
        processing_fees_cents:  fees[:processing].to_i,
        interchange_cents:      fees[:interchange].to_i,
        chargeback_fees_cents:  fees[:chargeback].to_i,
        payout_fees_cents:      fees[:payout].to_i,
        other_fees_cents:       fees[:other].to_i
      )
      fb.total!
      fb.save!
      fb
    end
  end
end