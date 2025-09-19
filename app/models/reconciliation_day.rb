# app/models/reconciliation_day.rb
class ReconciliationDay < ApplicationRecord
  has_many :reconciliation_variances, dependent: :delete_all
  enum :status, { pending: 0, ok: 1, warn: 2, error: 3 }

  validates :date, :currency, presence: true
  validates :date, uniqueness: { scope: %i[account_scope currency] }

  scope :for_range, ->(from, to) { where(date: from..to) }
  scope :recent_first, -> { order(date: :desc) }

  def compute_status!
    self.variance_cents = (computed_total_cents.to_i - statement_total_cents.to_i).abs
    self.status = if variance_cents.zero?
                    :ok
                  elsif variance_cents <= 50 # ≤ 0.50 in minor units
                    :warn
                  else
                    :error
                  end
    save!
  end
end

