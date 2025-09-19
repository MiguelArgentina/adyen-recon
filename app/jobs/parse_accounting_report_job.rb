# app/jobs/parse_accounting_report_job.rb
class ParseAccountingReportJob < ApplicationJob
  queue_as :default
  def perform(report_file_id)
    rf = ReportFile.find(report_file_id)
    Parse::Accounting.call(rf)
  end
end