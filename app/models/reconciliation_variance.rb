class ReconciliationVariance < ApplicationRecord
  belongs_to :reconciliation_day
  enum :kind, {
    missing_statement: 0, missing_accounting: 1, rounding: 2, fx_mismatch: 3,
    payout_timing: 4, fee_category_delta: 5, other: 9
  }
end
