class Payout < ApplicationRecord
  belongs_to :source_report_file, class_name: "ReportFile", optional: true
end
