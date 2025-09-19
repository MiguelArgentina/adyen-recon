class AllowNullOnReconciliationDaysAccountScope < ActiveRecord::Migration[8.0]
  def change
    change_column_null :reconciliation_days, :account_scope, true
  end
end
