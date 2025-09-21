class PayoutMatch < ApplicationRecord
  before_validation :normalize_account_scope

  enum :status, { unmatched: 0, matched: 1, partial: 2, conflict: 3 }

  private

  def normalize_account_scope
    self.account_scope = account_scope.presence
  end
end
