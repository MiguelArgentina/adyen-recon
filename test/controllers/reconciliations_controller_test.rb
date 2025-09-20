require "test_helper"

class ReconciliationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @date = Date.new(2025, 8, 6)
    @day = ReconciliationDay.create!(
      account_scope: nil,
      date: @date,
      currency: "USD",
      statement_total_cents: 3_168_509,
      accounting_total_cents: 9_510_159,
      computed_total_cents: 3_168_509,
      variance_cents: 0,
      status: :ok
    )
  end

  test "shows bank icon when payout records exist" do
    Payout.create!(
      booked_on: @date,
      currency: "USD",
      amount_minor: 100,
      status: "booked"
    )

    get reconciliations_path

    assert_response :success
    assert_includes response.body, "USD 💵 🏦"
  end

  test "omits bank icon when payout records are absent" do
    get reconciliations_path

    assert_response :success
    assert_includes response.body, "USD 💵"
    refute_includes response.body, "USD 💵 🏦"
  end
end
