require "test_helper"

class ReportFilesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
  end

  teardown do
    clear_enqueued_jobs
  end

  test "queues a single upload and redirects to show" do
    file = fixture_file_upload("files/sample_statement.csv", "text/csv")

    assert_difference -> { ReportFile.count }, 1 do
      assert_enqueued_with(job: ParseBalanceStatementJob) do
        post report_files_path, params: { report_file: { file: [file] } }, as: :multipart
      end
    end

    report_file = ReportFile.order(:created_at).last
    assert_redirected_to report_file_path(report_file)
    assert_equal "statement", report_file.kind
    assert_equal "pending", report_file.status
  end

  test "queues multiple uploads and redirects to index" do
    statement = fixture_file_upload("files/sample_statement.csv", "text/csv")
    accounting = fixture_file_upload("files/sample_accounting.csv", "text/csv")

    assert_enqueued_jobs 2, only: [ParseBalanceStatementJob, ParseAccountingReportJob] do
      assert_difference -> { ReportFile.count }, 2 do
        post report_files_path, params: { report_file: { file: [statement, accounting] } }, as: :multipart
      end
    end

    assert_redirected_to report_files_path
    kinds = ReportFile.order(:created_at).last(2).map(&:kind)
    assert_includes kinds, "statement"
    assert_includes kinds, "accounting"
  end
end
