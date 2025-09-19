# app/jobs/generate_export_job.rb
class GenerateExportJob < ApplicationJob
  queue_as :default
  def perform(export_file_id)
    ef = ExportFile.find(export_file_id)
    Rails.logger.info("[GenerateExportJob] start id=#{ef.id} kind=#{ef.kind} period=#{ef.period_start}..#{ef.period_end}")

    profile = ef.mapping_profile
    unless profile
      ef.update!(status: :failed, error: "Missing mapping profile")
      Rails.logger.error("[GenerateExportJob] missing mapping profile export=#{ef.id}")
      return
    end

    klass =
      case ef.kind.to_sym
      when :xero_csv       then GenerateExport::XeroCsv
      when :quickbooks_csv then GenerateExport::QuickbooksCsv
      when :generic_csv    then GenerateExport::QuickbooksCsv
      else
        Rails.logger.warn("[GenerateExportJob] unknown kind=#{ef.kind}, defaulting to QuickBooksCsv")
        GenerateExport::QuickbooksCsv
      end

    csv = klass.call(profile: profile, period_start: ef.period_start, period_end: ef.period_end)
    row_count = csv.to_s.lines.count - 1 # subtract header

    path = Rails.root.join("storage/exports", "#{SecureRandom.hex}.csv")
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, csv)

    ef.update!(status: :generated, file_path: path.to_s, bytes: File.size(path))
    Rails.logger.info("[GenerateExportJob] complete id=#{ef.id} bytes=#{ef.bytes} rows=#{row_count}")

    if row_count <= 0
      Rails.logger.info("[GenerateExportJob] export id=#{ef.id} generated empty data set (header only)")
    end
  rescue => e
    Rails.logger.error("[GenerateExportJob] failed id=#{export_file_id} error=#{e.class}: #{e.message}")
    ef.update!(status: :failed, error: e.message) rescue nil
    raise
  end

end