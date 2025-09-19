class ExportFile < ApplicationRecord
  belongs_to :mapping_profile, class_name: "MappingProfile"

  # Support both enum syntaxes (Rails < 7.1 and >= 7.1)
  if ActiveRecord.version >= Gem::Version.new("7.1.0")
    enum :kind,   { quickbooks_csv: 0, xero_csv: 1, generic_csv: 2 }
    enum :status, { queued: 0, generated: 1, failed: 2 }
  else
    enum kind:   { quickbooks_csv: 0, xero_csv: 1, generic_csv: 2 }
    enum status: { queued: 0, generated: 1, failed: 2 }
  end

  validates :period_start, :period_end, presence: true
  validate :period_range_valid

  private

  def period_range_valid
    return if period_start.blank? || period_end.blank?
    if period_end < period_start
      errors.add(:period_end, "must be on or after Period start")
    end
  end
end
