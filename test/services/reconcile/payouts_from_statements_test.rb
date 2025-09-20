require "test_helper"

module Reconcile
  class PayoutsFromStatementsTest < ActiveSupport::TestCase
    setup do
      @date = Date.new(2025, 8, 4)
      @credential = AdyenCredential.create!(label: "Test", auth_method: :password)
      @report_file = ReportFile.create!(
        adyen_credential: @credential,
        kind: :statement,
        reported_on: @date,
        currency: "USD"
      )
    end

    test "creates payouts for lowercase bank transfers with received status" do
      StatementLine.create!(
        report_file: @report_file,
        line_no: 1,
        occurred_on: @date,
        book_date: @date,
        category: "bank",
        type: "banktransfer",
        status: "received",
        amount_minor: 100,
        currency: "USD",
        transfer_id: "TRX-1"
      )

      assert_difference "Payout.count", 1 do
        PayoutsFromStatements.call(report_file: @report_file)
      end

      payout = Payout.last
      assert_equal @date, payout.booked_on
      assert_equal "USD", payout.currency
      assert_equal 100, payout.amount_minor
    end

    test "ignores bank transfers in unsupported statuses" do
      StatementLine.create!(
        report_file: @report_file,
        line_no: 1,
        occurred_on: @date,
        book_date: @date,
        category: "bank",
        type: "bankTransfer",
        status: "pending",
        amount_minor: 200,
        currency: "USD",
        transfer_id: "TRX-2"
      )

      assert_no_difference "Payout.count" do
        PayoutsFromStatements.call(report_file: @report_file)
      end
    end
  end
end
