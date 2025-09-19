require "test_helper"

class StatementAccountingReconciliationTest < ActiveSupport::TestCase
  setup do
    @credential = AdyenCredential.create!(label: "Test", auth_method: :password)
  end

  test "statement captures align with accounting captures" do
    statement_rf = build_report_file(kind: :statement, reported_on: Date.new(2025, 8, 1))
    attach_fixture(statement_rf, "sample_statement.csv")
    Parse::Statement.call(statement_rf)

    accounting_rf = build_report_file(kind: :accounting, reported_on: Date.new(2025, 8, 1))
    attach_fixture(accounting_rf, "sample_accounting.csv")
    Parse::Accounting.call(accounting_rf)

    day_one = Date.new(2025, 8, 1)
    day_two = Date.new(2025, 8, 2)

    expected_capture_minor = 566_397

    assert_equal expected_capture_minor, Sources::Accounting.total_for(nil, day_one, "USD")
    assert_equal expected_capture_minor, Sources::Computed.total_for(nil, day_one, "USD")
    assert_equal expected_capture_minor, Sources::Statement.total_for(nil, day_one, "USD")

    assert_equal 0, Sources::Accounting.total_for(nil, day_two, "USD")
    assert_equal 0, Sources::Computed.total_for(nil, day_two, "USD")
    assert_equal 0, Sources::Statement.total_for(nil, day_two, "USD")

    day_record = Recon::BuildDaily.new(account_scope: nil, date: day_one, currency: "USD").call
    assert_equal expected_capture_minor, day_record.statement_total_cents
    assert_equal expected_capture_minor, day_record.computed_total_cents
    assert_equal :ok, day_record.status.to_sym
  end

  private

  def build_report_file(kind:, reported_on:)
    ReportFile.create!(adyen_credential: @credential, kind: kind, reported_on: reported_on, currency: "USD")
  end

  def attach_fixture(report_file, filename)
    path = Rails.root.join("test/fixtures/files", filename)
    File.open(path) do |file|
      report_file.file.attach(io: file, filename: filename, content_type: "text/csv")
    end
  end
end
