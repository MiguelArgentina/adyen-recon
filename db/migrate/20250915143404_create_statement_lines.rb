class CreateStatementLines < ActiveRecord::Migration[8.0]
  def change
    create_table :statement_lines do |t|
      t.references :report_file, null: false, foreign_key: true
      t.integer :line_no
      t.date :occurred_on
      t.date :book_date
      t.string :category
      t.string :type
      t.string :status
      t.bigint :amount_minor
      t.string :currency
      t.bigint :balance_before_minor
      t.bigint :balance_after_minor
      t.string :balance_account_id
      t.string :balance_account_code
      t.string :reference
      t.string :transfer_id
      t.string :payout_id
      t.string :description
      t.string :counterparty

      t.timestamps
    end
    add_index :statement_lines, [:book_date, :category, :type, :payout_id, :transfer_id]
  end
end
