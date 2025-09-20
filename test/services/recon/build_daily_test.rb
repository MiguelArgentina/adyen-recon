# frozen_string_literal: true

require "test_helper"

module Recon
  class BuildDailyTest < ActiveSupport::TestCase
    setup do
      @date = Date.new(2023, 1, 1)
      @currency = "USD"

      ReconciliationDay.create!(account_scope: nil, date: @date, currency: @currency, status: :pending)

      now = Time.current
      connection = ReconciliationDay.connection
      connection.execute <<~SQL.squish
        INSERT INTO #{ReconciliationDay.table_name}
          (account_scope, date, currency, status, created_at, updated_at)
        VALUES
          (NULL, #{connection.quote(@date)}, #{connection.quote(@currency)}, 0, #{connection.quote(now)}, #{connection.quote(now)})
      SQL
    end

    test "rebuild removes duplicate days before saving" do
      scope = nil
      relation = ReconciliationDay.where(account_scope: scope, date: @date, currency: @currency)
      assert_equal 2, relation.count, "expected duplicate rows for setup"

      statement_total = 10
      computed_total = 10
      accounting_total = 12

      Sources::Statement.stub(:total_for, statement_total) do
        Sources::Accounting.stub(:total_for, accounting_total) do
          Sources::Computed.stub(:total_for, computed_total) do
            noop_explainer = Struct.new(:call).new(true)
            Recon::ExplainVariance.stub(:new, ->(_) { noop_explainer }) do
              day = Recon::BuildDaily.new(account_scope: scope, date: @date, currency: @currency).call

              assert_equal 1, relation.count
              assert_equal statement_total, day.reload.statement_total_cents
              assert_equal accounting_total, day.accounting_total_cents
              assert_equal "ok", day.status
            end
          end
        end
      end
    end
  end
end
