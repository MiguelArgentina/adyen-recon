# db/migrate/XXXXXXXXXXXXXX_create_reconciliation_variances.rb
class CreateReconciliationVariances < ActiveRecord::Migration[7.1]
  def change
    create_table :reconciliation_variances do |t|
      t.references :reconciliation_day, null: false, foreign_key: true

      t.integer :kind, null: false, default: 9   # 9=other (see model)
      t.bigint  :amount_cents, null: false, default: 0
      t.jsonb   :payload, null: false, default: {}

      t.timestamps
    end

    add_index :reconciliation_variances, :kind
  end
end
