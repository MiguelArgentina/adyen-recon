# app/controllers/report_files_controller.rb
require 'csv'
class ReportFilesController < ApplicationController
  def index
    @files = ReportFile.order(created_at: :desc)
  end

  def show
    @file = ReportFile.find(params[:id])
    @stats = (@file.respond_to?(:settings) && @file.settings.is_a?(Hash)) ? @file.settings.symbolize_keys : {}
    if @file.statement?
      @sample_lines = @file.statement_lines.order(:line_no).limit(100)
    elsif @file.accounting?
      @sample_lines = @file.accounting_entries.order(:line_no).limit(100)
    else
      @sample_lines = []
    end
  end

  def new
    @file = ReportFile.new
  end

  def create
    @file = ReportFile.new(report_file_params.except(:file))
    uploaded = report_file_params[:file]

    # Attach file first so detection can use it
    if uploaded.present?
      Rails.logger.info("[ReportFiles#create] Received upload: original_filename=#{uploaded.original_filename} size=#{uploaded.size}")
      @file.file.attach(uploaded)
      Rails.logger.info("[ReportFiles#create] Attachment persisted?=#{@file.file.attached?}")
      auto_detect_kind_if_needed(uploaded)
    else
      Rails.logger.warn("[ReportFiles#create] No file parameter provided")
    end

    ensure_default_credential!

    # Assign credential before validations
    if @file.adyen_credential.blank?
      @file.adyen_credential = AdyenCredential.first
      Rails.logger.info("[ReportFiles#create] Assigned default credential id=#{@file.adyen_credential&.id}")
    end
    @file.status ||= :pending

    if @file.kind.blank?
      @file.errors.add(:kind, "could not be auto-detected; please choose (detection failed or low confidence)")
      Rails.logger.warn("[ReportFiles#create] Kind undetected – prompting user")
      return render :new, status: :unprocessable_entity
    end

    replacement_info = nil
    if @file.reported_on.present?
      replacement_info = prior_data_replacement_preview(@file.kind, @file.reported_on)
    end

    if @file.save
      if replacement_info && replacement_info[:rows] > 0
        replace_prior_data!(@file.kind, @file.reported_on)
        Rails.logger.info("[ReportFiles#create] Replaced prior data kind=#{@file.kind} day=#{@file.reported_on} rows=#{replacement_info[:rows]}")
        flash_notice = "Upload received. Parsing… Replaced #{replacement_info[:rows]} existing row(s) for #{@file.reported_on}."
      else
        flash_notice = "Upload received. Parsing…"
      end
      enqueue_parser(@file)
      redirect_to report_file_path(@file), notice: flash_notice
    else
      Rails.logger.error("[ReportFiles#create] Save failed: #{@file.errors.full_messages.join('; ')}")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def ensure_default_credential!
    return if AdyenCredential.exists?
    cred = AdyenCredential.create(label: "Default", auth_method: :password)
    if cred.persisted?
      Rails.logger.info("[ReportFiles#create] Created default AdyenCredential id=#{cred.id}")
    else
      Rails.logger.error("[ReportFiles#create] Failed to create default credential: #{cred.errors.full_messages.join(', ')}")
    end
  end

  def report_file_params
    params.require(:report_file).permit(:kind, :reported_on, :account_code, :account_id, :currency, :file)
  end

  def auto_detect_kind_if_needed(uploaded)
    return unless @file.kind.blank? && uploaded.respond_to?(:read)
    begin
      tf = uploaded.tempfile
      tf.rewind
      header_line = nil
      10.times do
        raw = tf.gets
        break unless raw
        cleaned = raw.encode('UTF-8', invalid: :replace, undef: :replace).gsub(/\r\n?/, "\n")
        next if cleaned.strip.empty? || cleaned.start_with?('#')
        header_line = cleaned
        break
      end
      unless header_line
        Rails.logger.warn("[ReportFiles#create] No header line found within first 10 lines")
        return
      end
      header_line.sub!("\uFEFF", '')
      parsed_headers = (CSV.parse_line(header_line) rescue nil) || header_line.split(',')
      headers = Array(parsed_headers).map { |h| h.to_s.strip.sub("\uFEFF", '') }
      detection = ReportFile.detect_kind_by_headers(headers)
      Rails.logger.info("[ReportFiles#create] Header detection: #{detection.inspect}")

      if detection[:detected].present?
        if detection[:exact]
          @file.kind = detection[:detected]
        else
          penalty = detection[:missing].size + detection[:unexpected].size + detection[:order_mismatches].size
          if penalty <= 4 # allow minor deviations
            @file.kind = detection[:detected]
            Rails.logger.info("[ReportFiles#create] Assigned kind=#{@file.kind} with minor header deviations (penalty=#{penalty})")
          else
            Rails.logger.warn("[ReportFiles#create] Ambiguous or severe header deviations (penalty=#{penalty}); requiring manual selection")
          end
        end
      else
        Rails.logger.warn("[ReportFiles#create] Unable to detect kind from headers")
      end

      # Add validation message if deviations severe and kind assigned
      if @file.kind.present? && !detection[:exact]
        significant = detection[:missing].any? || detection[:unexpected].any? || detection[:order_mismatches].any?
        if significant
          @file.errors.add(:base, "Headers deviated from expected #{detection[:detected]} format. Missing: #{detection[:missing].join('; ')} Unexpected: #{detection[:unexpected].take(5).join('; ')}") if penalty > 4
        end
      end
    rescue => e
      Rails.logger.error("[ReportFiles#create] Header detection error: #{e.class}: #{e.message}\n#{e.backtrace.first(3).join('; ')}")
    ensure
      uploaded.tempfile.rewind if uploaded.respond_to?(:tempfile)
    end
  end

  def enqueue_parser(file)
    case file.kind.to_sym
    when :statement then ParseBalanceStatementJob.perform_later(file.id)
    when :accounting then ParseAccountingReportJob.perform_later(file.id)
    else
      # ignore SDR for MVP
    end
  end

  def prior_data_replacement_preview(kind, day)
    return { rows: 0 } if day.blank?
    rows = if kind.to_s == 'statement'
             StatementLine.where(book_date: day).count
           else
             AccountingEntry.where(book_date: day).count
           end
    { rows: rows }
  end

  def replace_prior_data!(kind, day)
    return if day.blank?
    if kind.to_s == 'statement'
      StatementLine.where(book_date: day).delete_all
    else
      AccountingEntry.where(book_date: day).delete_all
    end
    DailySummary.where(day: day).delete_all
  end
end
