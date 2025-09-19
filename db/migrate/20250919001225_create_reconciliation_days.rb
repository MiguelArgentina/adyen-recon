# db/migrate/XXXXXXXXXXXXXX_create_reconciliation_days.rb
class CreateReconciliationDays < ActiveRecord::Migration[7.1]
  def change
    create_table :reconciliation_days do |t|
      t.string :account_scope, null: false
      t.date   :date,          null: false
      t.string :currency,      null: false

      t.bigint :statement_total_cents
      t.bigint :accounting_total_cents
      t.bigint :computed_total_cents
      t.bigint :variance_cents

      # enum in Rails is just an integer column
      t.integer :status, null: false, default: 0  # 0=pending, 1=ok, 2=warn, 3=error

      t.text :notes
      t.timestamps
    end

    # Fast filters
    add_index :reconciliation_days, :date
    add_index :reconciliation_days, [:account_scope, :date, :currency],
              unique: true, name: "idx_recon_days_scope_date_curr_unique"
  end
end
