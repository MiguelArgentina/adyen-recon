require "test_helper"

module Recon
  class PayoutMatcherTest < ActiveSupport::TestCase
    setup do
      @credential = AdyenCredential.create!(label: "Test", auth_method: :password)
      @statement_file = ReportFile.create!(
        adyen_credential: @credential,
        kind: :statement,
        reported_on: Date.new(2025, 8, 1),
        currency: "USD"
      )
      @payout_file = ReportFile.create!(
        adyen_credential: @credential,
        kind: :statement,
        reported_on: Date.new(2025, 8, 1),
        currency: "USD"
      )
    end

    test "stores capture transactions between payouts" do
      previous_payout_date = Date.new(2025, 8, 3)
      payout_date          = Date.new(2025, 8, 5)

      Payout.create!(
        bank_transfer_id: "PREV-1",
        booked_on: previous_payout_date,
        currency: "USD",
        amount_minor: -50_000,
        payout_ref: "PREV",
        source_report_file: @payout_file
      )

      current_payout = Payout.create!(
        bank_transfer_id: "CURR-1",
        booked_on: payout_date,
        currency: "USD",
        amount_minor: -30_000,
        payout_ref: "CURR",
        source_report_file: @payout_file
      )

      StatementLine.create!(
        report_file: @statement_file,
        line_no: 1,
        occurred_on: previous_payout_date - 1,
        book_date: previous_payout_date - 1,
        category: "payment",
        type: "capture",
        amount_minor: 10_000,
        currency: "USD",
        reference: "IGNORED-1"
      )

      StatementLine.create!(
        report_file: @statement_file,
        line_no: 2,
        occurred_on: previous_payout_date + 1,
        book_date: previous_payout_date + 1,
        category: "payment",
        type: "capture",
        amount_minor: 12_000,
        currency: "USD",
        reference: "MATCH-1"
      )

      StatementLine.create!(
        report_file: @statement_file,
        line_no: 3,
        occurred_on: payout_date,
        book_date: payout_date - 1,
        category: "platformPayment",
        type: "Capture",
        amount_minor: 18_000,
        currency: "USD",
        reference: "MATCH-2"
      )

      StatementLine.create!(
        report_file: @statement_file,
        line_no: 4,
        occurred_on: payout_date,
        book_date: payout_date,
        category: "platformPayment",
        type: "Capture",
        amount_minor: 5_000,
        currency: "USD",
        reference: "IGNORED-2"
      )

      Recon::PayoutMatcher.new(account_scope: nil, bank_lines: [], date: payout_date, currency: "USD").call

      match = PayoutMatch.find_by!(adyen_payout_id: "CURR-1")
      assert_equal "matched", match.status

      details = match.details.deep_symbolize_keys
      assert_equal previous_payout_date.to_s, details[:transactions_period_start]

      transactions = details[:transactions]
      assert_equal 2, transactions.length
      assert_equal ["MATCH-1", "MATCH-2"], transactions.map { |tx| tx[:reference] }
      assert_equal [previous_payout_date + 1, payout_date - 1].map(&:to_s),
                   transactions.map { |tx| tx[:value_date] }

      assert_equal 30_000, details[:transactions_total_cents]
      assert_equal 30_000, match.adyen_amount_cents.abs
    end

    test "normalizes currencies when matching payouts" do
      payout_date = Date.new(2025, 8, 5)

      Payout.create!(
        bank_transfer_id: "CURR-LOW",
        booked_on: payout_date,
        currency: "usd",
        amount_minor: -30_000,
        payout_ref: "CURR-LOW",
        source_report_file: @payout_file
      )

      StatementLine.create!(
        report_file: @statement_file,
        line_no: 1,
        occurred_on: payout_date - 1,
        book_date: payout_date - 1,
        category: "payment",
        type: "capture",
        amount_minor: 30_000,
        currency: "USD",
        reference: "MATCH-LOW"
      )

      bank_lines = [
        { date: payout_date, currency: "usd", amount_cents: -30_000, ref: "BANK-LOW" }
      ]

      Recon::PayoutMatcher.new(account_scope: nil, bank_lines:, date: payout_date, currency: "usd").call

      match = PayoutMatch.find_by!(adyen_payout_id: "CURR-LOW")
      assert_equal "matched", match.status
      assert_equal "BANK-LOW", match.bank_ref
      assert_equal(-30_000, match.bank_amount_cents)

      details = match.details.deep_symbolize_keys
      assert_equal 30_000, details[:transactions_total_cents]
    end

    test "marks payouts as unmatched when transactions are booked on the payout date" do
      payout_date = Date.new(2025, 8, 10)

      Payout.create!(
        bank_transfer_id: "CURR-SAME-DAY",
        booked_on: payout_date,
        currency: "USD",
        amount_minor: -15_000,
        payout_ref: "CURR-SAME-DAY",
        source_report_file: @payout_file
      )

      StatementLine.create!(
        report_file: @statement_file,
        line_no: 1,
        occurred_on: payout_date,
        book_date: payout_date,
        category: "payment",
        type: "capture",
        amount_minor: 15_000,
        currency: "USD",
        reference: "CAPTURE-SAME-DAY"
      )

      Recon::PayoutMatcher.new(account_scope: nil, bank_lines: [], date: payout_date, currency: "USD").call

      match = PayoutMatch.find_by!(adyen_payout_id: "CURR-SAME-DAY")
      assert_equal "unmatched", match.status

      details = match.details.deep_symbolize_keys
      assert_equal [], details[:transactions]
      assert_equal 0, details[:transactions_total_cents]
    end
  end
end
