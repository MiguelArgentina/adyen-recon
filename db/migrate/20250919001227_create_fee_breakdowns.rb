# db/migrate/XXXXXXXXXXXXXX_create_fee_breakdowns.rb
class CreateFeeBreakdowns < ActiveRecord::Migration[7.1]
  def change
    create_table :fee_breakdowns do |t|
      t.string :account_scope, null: false
      t.date   :date,          null: false
      t.string :currency,      null: false

      t.bigint :scheme_fees_cents,     default: 0
      t.bigint :processing_fees_cents, default: 0
      t.bigint :interchange_cents,     default: 0
      t.bigint :chargeback_fees_cents, default: 0
      t.bigint :payout_fees_cents,     default: 0
      t.bigint :other_fees_cents,      default: 0
      t.bigint :total_fees_cents,      default: 0

      t.timestamps
    end

    add_index :fee_breakdowns, [:account_scope, :date, :currency],
              unique: true, name: "idx_fee_breakdowns_scope_date_curr_unique"
  end
end
