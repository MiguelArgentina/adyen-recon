# app/controllers/exports_controller.rb
class ExportsController < ApplicationController
  def index
    @exports = ExportFile.order(created_at: :desc).limit(200)
  end

  def new
    @export = ExportFile.new
  end

  def create
    @export = ExportFile.new(export_params.merge(status: :queued))
    if @export.save
      GenerateExportJob.perform_later(@export.id)
      redirect_to export_path(@export), notice: "Export queued."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @export = ExportFile.find(params[:id])
    if @export.generated? && @export.file_path.present? && File.exist?(@export.file_path)
      begin
        # Count data rows (excluding header) cheaply without loading entire file
        line_count = 0
        File.foreach(@export.file_path) { |l| line_count += 1 }
        @row_count = [line_count - 1, 0].max
      rescue => e
        Rails.logger.warn("[ExportsController#show] row count failed export=#{@export.id} #{e.class}: #{e.message}")
        @row_count = nil
      end
    else
      @row_count = nil
    end
  end

  def download
    @export = ExportFile.find(params[:id])
    unless @export.generated? && @export.file_path.present? && File.exist?(@export.file_path)
      redirect_to export_path(@export), alert: "File not ready yet." and return
    end
    send_file @export.file_path, filename: File.basename(@export.file_path), type: "text/csv"
  end

  private

  def export_params
    # Support current form (export_file) and legacy (:export) if any
    key = params.key?(:export_file) ? :export_file : :export
    params.require(key).permit(:kind, :mapping_profile_id, :period_start, :period_end)
  end
end
