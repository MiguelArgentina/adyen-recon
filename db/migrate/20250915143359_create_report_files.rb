class CreateReportFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :report_files do |t|
      t.integer :kind
      t.integer :status
      t.date :reported_on
      t.string :account_code
      t.string :account_id
      t.string :currency
      t.string :original_filename
      t.bigint :bytes
      t.string :checksum
      t.text :error
      t.references :adyen_credential, null: false, foreign_key: true

      t.timestamps
    end
    add_index :report_files, [:kind, :status, :reported_on]
  end
end
