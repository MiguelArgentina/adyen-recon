class CreateAccountingEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :accounting_entries do |t|
      t.references :report_file, null: false, foreign_key: true
      t.integer :line_no
      t.date :occurred_on
      t.date :book_date
      t.string :direction
      t.string :category
      t.string :type
      t.string :subcategory
      t.string :status
      t.bigint :amount_minor
      t.string :currency
      t.string :balance_account_id
      t.string :balance_account_code
      t.string :psp_reference
      t.string :transfer_id
      t.string :payout_id
      t.string :reference
      t.string :description

      t.timestamps
    end
    add_index :accounting_entries, [:book_date, :category, :type, :transfer_id, :payout_id]
  end
end
