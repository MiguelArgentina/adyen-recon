class AllowNullOnFeeBreakdownsAccountScope < ActiveRecord::Migration[8.0]
  def change
    change_column_null :fee_breakdowns, :account_scope, true
  end
end
