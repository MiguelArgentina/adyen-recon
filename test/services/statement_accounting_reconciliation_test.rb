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

  test "statement capture totals use value date when present" do
    statement_rf = build_report_file(kind: :statement, reported_on: Date.new(2025, 9, 5))
    attach_fixture(statement_rf, "value_date_statement.csv")
    Parse::Statement.call(statement_rf)

    accounting_rf = build_report_file(kind: :accounting, reported_on: Date.new(2025, 9, 5))
    attach_fixture(accounting_rf, "value_date_accounting.csv")
    Parse::Accounting.call(accounting_rf)

    assert_equal :parsed_ok, statement_rf.reload.status.to_sym
    assert_equal :parsed_ok, accounting_rf.reload.status.to_sym

    value_day = Date.new(2025, 9, 5)
    earlier_day = Date.new(2025, 9, 3)
    expected_minor = 1_230

    assert_equal expected_minor, Sources::Accounting.total_for(nil, value_day, "USD")
    assert_equal expected_minor, Sources::Computed.total_for(nil, value_day, "USD")
    assert_equal expected_minor, Sources::Statement.total_for(nil, value_day, "USD")

    assert_equal 0, Sources::Statement.total_for(nil, earlier_day, "USD")

    capture_line = StatementLine.find_by(report_file: statement_rf, transfer_id: "TRF-CAP-002")
    refute_nil capture_line
    assert_equal value_day, capture_line.book_date
  end

  test "computed totals favor statement data when accounting is inflated" do
    day = Date.new(2025, 8, 3)

    statement_rf = build_report_file(kind: :statement, reported_on: day)
    accounting_rf = build_report_file(kind: :accounting, reported_on: day)

    StatementLine.create!(
      report_file: statement_rf,
      line_no: 1,
      occurred_on: day,
      book_date: day,
      category: "platformpayment",
      type: "capture",
      status: "booked",
      amount_minor: 220_555,
      currency: "USD"
    )

    AccountingEntry.create!(
      report_file: accounting_rf,
      line_no: 1,
      occurred_on: day,
      book_date: day,
      category: "platformpayment",
      type: "capture",
      status: "booked",
      amount_minor: 220_555,
      currency: "USD"
    )

    AccountingEntry.create!(
      report_file: accounting_rf,
      line_no: 2,
      occurred_on: day,
      book_date: day,
      category: "platformpayment",
      type: "capture",
      status: "booked",
      amount_minor: 534_389,
      currency: "USD"
    )

    assert_equal 220_555, Sources::Statement.total_for(nil, day, "USD")
    assert_equal 754_944, Sources::Accounting.total_for(nil, day, "USD")
    assert_equal 220_555, Sources::Computed.total_for(nil, day, "USD")
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
