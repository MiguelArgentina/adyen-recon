class AddSettingsToReportFiles < ActiveRecord::Migration[7.1]
  def change
    add_column :report_files, :settings, :jsonb, default: {}, null: false
    add_index  :report_files, :settings, using: :gin
  end
end

