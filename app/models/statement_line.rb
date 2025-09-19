class StatementLine < ApplicationRecord
  self.inheritance_column = :_type_disabled
  belongs_to :report_file
  before_validation :normalize_kinds

  private
  def normalize_kinds
    self.category = category.to_s.strip.downcase.presence
    self.type     = type.to_s.strip.downcase.presence
  end
end
