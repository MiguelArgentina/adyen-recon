# app/jobs/parse_balance_statement_job.rb
class ParseBalanceStatementJob < ApplicationJob
  queue_as :default
  def perform(report_file_id)
    rf = ReportFile.find(report_file_id)
    Parse::Statement.call(rf)
    Reconcile::PayoutsFromStatements.call(report_file: rf)
  end
end