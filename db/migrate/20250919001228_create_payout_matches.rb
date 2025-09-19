class CreatePayoutMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :payout_matches do |t|
      t.string :account_scope
      t.date :payout_date
      t.string :currency
      t.string :adyen_payout_id
      t.bigint :adyen_amount_cents
      t.string :bank_ref
      t.bigint :bank_amount_cents
      t.integer :status
      t.jsonb :details

      t.timestamps
    end
  end
end
