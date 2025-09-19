class CreatePayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :payouts do |t|
      t.string :bank_transfer_id
      t.string :payout_ref
      t.date :booked_on
      t.string :currency
      t.bigint :amount_minor
      t.bigint :fee_minor
      t.string :status
      t.bigint :source_report_file_id

      t.timestamps
    end
    add_foreign_key :payouts, :report_files, column: :source_report_file_id
    add_index :payouts, :source_report_file_id
  end
end
