class CreateExportFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :export_files do |t|
      t.integer :kind
      t.integer :status
      t.references :mapping_profile, null: false, foreign_key: true
      t.date :period_start
      t.date :period_end
      t.string :file_path
      t.bigint :bytes
      t.string :checksum
      t.text :error

      t.timestamps
    end
  end
end
