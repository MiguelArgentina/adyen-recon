# lib/tasks/maintenance.rake
# Housekeeping / maintenance tasks

namespace :report_files do
  desc "Backfill legacy parsed statuses into parsed_ok / parsed_with_errors based on settings row error + skip counts"
  task backfill_parsed_status: :environment do
    updated_ok = 0
    updated_err = 0
    skipped = 0
    ReportFile.where(status: :parsed).find_each do |rf|
      stats = rf.settings.is_a?(Hash) ? rf.settings : {}
      errors = stats['row_errors_count'].to_i
      skipped_rows = stats['rows_skipped'].to_i
      if errors.zero? && skipped_rows.zero?
        rf.update_columns(status: ReportFile.statuses[:parsed_ok])
        updated_ok += 1
      else
        rf.update_columns(status: ReportFile.statuses[:parsed_with_errors])
        updated_err += 1
      end
    rescue => e
      skipped += 1
      puts "Skipping id=#{rf.id} due to #{e.class}: #{e.message}" if ENV['VERBOSE']
    end
    puts "Backfill complete: parsed_ok=#{updated_ok} parsed_with_errors=#{updated_err} skipped=#{skipped}"
  end
end

namespace :exports do
  desc "Verify generated exports still have files on disk; mark failed if missing"
  task verify_files: :environment do
    missing = 0
    ok = 0
    ExportFile.where(status: :generated).find_each do |ex|
      if ex.file_path.present? && File.exist?(ex.file_path)
        ok += 1
      else
        ex.update_columns(status: ExportFile.statuses[:failed], error: 'File missing on disk')
        missing += 1
      end
    end
    puts "Verification complete: ok=#{ok} missing_marked_failed=#{missing}"
  end

  desc "Remove orphaned export files on disk not referenced in DB (dry-run unless FORCE=1)"
  task cleanup_orphans: :environment do
    export_dir = Rails.root.join('storage','exports')
    unless Dir.exist?(export_dir)
      puts "No export directory found: #{export_dir}"; next
    end
    db_paths = ExportFile.where.not(file_path: nil).pluck(:file_path).map(&:to_s).to_set
    orphans = Dir.glob(export_dir.join('*.csv')).reject { |p| db_paths.include?(p) }
    if orphans.empty?
      puts 'No orphaned files.'; next
    end
    if ENV['FORCE'] == '1'
      orphans.each { |p| File.delete(p) rescue nil }
      puts "Deleted #{orphans.size} orphaned files."
    else
      puts "Orphaned files (dry run):\n - #{orphans.join("\n - ")}\n(Set FORCE=1 to delete)"
    end
  end
end

