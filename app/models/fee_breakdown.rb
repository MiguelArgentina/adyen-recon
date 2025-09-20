class FeeBreakdown < ApplicationRecord
  validates :date, :currency, presence: true
  validates :account_scope, presence: true, unless: -> { account_scope.nil? }

  def total!
    self.total_fees_cents = %i[
      scheme_fees_cents processing_fees_cents interchange_cents
      chargeback_fees_cents payout_fees_cents other_fees_cents
    ].sum { |k| self[k].to_i }
  end
end