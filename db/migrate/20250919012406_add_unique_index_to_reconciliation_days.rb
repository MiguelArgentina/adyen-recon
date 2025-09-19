class AddUniqueIndexToReconciliationDays < ActiveRecord::Migration[8.0]
  def change
    add_index :reconciliation_days, [:account_scope, :date, :currency],
              unique: true, name: "idx_recon_days_scope_date_currency_unique"
  end
end
