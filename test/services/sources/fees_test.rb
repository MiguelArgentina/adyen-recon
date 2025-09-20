require "test_helper"

module Sources
  class FeesTest < ActiveSupport::TestCase
    setup do
      @date = Date.new(2025, 8, 25)
      @credential = AdyenCredential.create!(label: "Test", auth_method: :password)
      @report_file = ReportFile.create!(
        adyen_credential: @credential,
        kind: :accounting,
        reported_on: @date,
        currency: "USD"
      )
      @line_no = 0
    end

    test "categorizes accounting entries into fee buckets" do
      create_entry(amount: -150, category: "platformpayment", type: "scheme fee", description: "Visa scheme fee")
      create_entry(amount: -275, category: "platformpayment", type: "commission", description: "Processing fee")
      create_entry(amount: -125, category: "platformpayment", type: "interchange", description: "Interchange fee")
      create_entry(amount: -300, category: "chargeback", type: "fee", description: "Chargeback fee")
      create_entry(amount: -95, category: "bank", type: "banktransfer", description: "Bank transfer fee")
      create_entry(amount: -60, category: "platformpayment", type: "adjustment", description: "Regulatory fee")

      result = Sources::Fees.for(nil, @date, "USD")

      assert_equal(-150, result[:scheme])
      assert_equal(-275, result[:processing])
      assert_equal(-125, result[:interchange])
      assert_equal(-300, result[:chargeback])
      assert_equal(-95, result[:payout])
      assert_equal(-60, result[:other])
    end

    test "ignores non fee accounting entries" do
      create_entry(amount: 5_000, category: "platformpayment", type: "capture", description: "Successful capture")

      result = Sources::Fees.for(nil, @date, "USD")

      assert_equal({
        scheme: 0,
        processing: 0,
        interchange: 0,
        chargeback: 0,
        payout: 0,
        other: 0
      }, result)
    end

    test "filters by scope and uses currency fallback" do
      scoped_report = ReportFile.create!(
        adyen_credential: @credential,
        kind: :accounting,
        reported_on: @date,
        currency: "USD",
        account_code: "SCOPE-123"
      )

      create_entry(amount: -200, category: "platformpayment", type: "commission", description: "Processing fee")
      create_entry(amount: -80, category: "bank", type: "fee", description: "Payout fee", report_file: scoped_report, currency: nil)

      nil_scope_result = Sources::Fees.for(nil, @date, "USD")
      scoped_result = Sources::Fees.for("SCOPE-123", @date, "USD")

      assert_equal(-200, nil_scope_result[:processing])
      assert_equal(0, nil_scope_result[:payout])

      assert_equal(-80, scoped_result[:payout])
      assert_equal(0, scoped_result[:processing])
    end

    private

    def create_entry(amount:, category:, type:, description:, subcategory: nil, report_file: @report_file, currency: "USD")
      @line_no += 1

      AccountingEntry.create!(
        report_file: report_file,
        line_no: @line_no,
        occurred_on: @date,
        book_date: @date,
        category: category,
        type: type,
        subcategory: subcategory,
        status: "booked",
        amount_minor: amount,
        currency: currency,
        reference: nil,
        description: description
      )
    end
  end
end
