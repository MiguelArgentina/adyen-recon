class PayoutMatch < ApplicationRecord
  enum :status, { unmatched: 0, matched: 1, partial: 2, conflict: 3 }
end
