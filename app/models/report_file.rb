class ReportFile < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :adyen_credential
  has_one_attached :file
  has_many :statement_lines, dependent: :delete_all
  has_many :accounting_entries, dependent: :delete_all

  enum :kind, { statement: 0, accounting: 1 }
  enum :status, { pending: 0, parsed: 1, failed: 2, parsed_with_errors: 3, parsed_ok: 4 }

  after_create_commit :broadcast_row_append
  after_update_commit :broadcast_status_refresh

  validates :kind, presence: true
  # reported_on becomes optional; we fill it automatically if blank

  before_validation :set_defaults

  STATEMENT_HEADERS = [
    "BalancePlatform","AccountHolder","BalanceAccount","Category","Type","Status","Transfer Id","Transaction Id",
    "Psp Payment Merchant Reference","Psp Payment Psp Reference","Psp Modification Psp Reference","Psp Modification Merchant Reference",
    "Reference","Description","Booking Date","Booking Date TimeZone","Value Date","Value Date TimeZone","Currency","Amount",
    "Starting Balance Currency","Starting Balance","Ending Balance Currency","Ending Balance",
    "Reserved1","Reserved2","Reserved3","Reserved4","Reserved5","Reserved6","Reserved7","Reserved8","Reserved9","Reserved10"
  ].freeze

  ACCOUNTING_HEADERS = [
    "BalancePlatform","AccountHolder","BalanceAccount","Transfer Id","Transaction Id","Category","Status","Type",
    "Booking Date","Booking Date TimeZone","Value Date","Value Date TimeZone","Currency","Amount","Original Currency",
    "Original Amount","Payment Currency","Received (PC)","Reserved (PC)","Balance (PC)","Reference","Description",
    "Counterparty Balance Account Id","Psp Payment Merchant Reference","Psp Payment Psp Reference","Psp Modification Psp Reference",
    "Psp Modification Merchant Reference","Payment Instrument Type","Payment Instrument Id","Entrymode","Auth Code","Shopper Interaction",
    "MCC","Counterparty Name","Counterparty Address","Counterparty City","Counterparty Country","Counterparty iban","Counterparty bic",
    "Counterparty Account Number","Counterparty Postal Code","Interchange Currency","Interchange","Beneficiary Balance Account",
    "Brand Variant","Reference for Beneficiary","Platform Payment Interchange","Platform Payment Scheme Fee","Platform Payment Markup",
    "Platform Payment Commission","Platform Payment Cost Currency","Account Holder Description","Account Holder Reference",
    "Balance Account Description","Balance Account Reference","Reserved1","Reserved2","Reserved3","Reserved4","Reserved5",
    "Reserved6","Reserved7","Reserved8","Reserved9","Reserved10"
  ].freeze

  # Normalizes header array (trim) without case modification so we can compare exact order & names
  def self.normalize_headers(arr)
    Array(arr).map { |h| h.to_s.strip }
  end

  # Returns a detection result hash:
  # { detected: :statement|:accounting|nil, exact: true/false, missing: [...], unexpected: [...], order_mismatches: [[index, expected, actual], ...] }
  def self.detect_kind_by_headers(raw_headers)
    headers = normalize_headers(raw_headers)
    if headers == STATEMENT_HEADERS
      return { detected: :statement, exact: true, missing: [], unexpected: [], order_mismatches: [] }
    elsif headers == ACCOUNTING_HEADERS
      return { detected: :accounting, exact: true, missing: [], unexpected: [], order_mismatches: [] }
    end

    # Compute diffs for each expected list
    s_diff = diff_headers(headers, STATEMENT_HEADERS)
    a_diff = diff_headers(headers, ACCOUNTING_HEADERS)

    # Heuristic: choose list with lowest combined penalty (missing + unexpected + order mismatches)
    s_penalty = s_diff[:missing].size + s_diff[:unexpected].size + s_diff[:order_mismatches].size
    a_penalty = a_diff[:missing].size + a_diff[:unexpected].size + a_diff[:order_mismatches].size

    chosen = nil
    chosen_diff = nil
    if s_penalty < a_penalty
      chosen = :statement
      chosen_diff = s_diff
    elsif a_penalty < s_penalty
      chosen = :accounting
      chosen_diff = a_diff
    else
      # tie => ambiguous
      chosen = nil
      chosen_diff = { missing: [], unexpected: [], order_mismatches: [] }
    end

    { detected: chosen, exact: false, missing: chosen_diff[:missing], unexpected: chosen_diff[:unexpected], order_mismatches: chosen_diff[:order_mismatches] }
  end

  def self.diff_headers(actual, expected)
    missing = expected - actual
    unexpected = actual - expected
    order_mismatches = []
    # Check only up to min length
    [actual.length, expected.length].min.times do |i|
      if actual[i] != expected[i]
        order_mismatches << [i, expected[i], actual[i]]
      end
    end
    { missing: missing, unexpected: unexpected, order_mismatches: order_mismatches }
  end

  def self.expected_headers_for(kind)
    kind.to_sym == :statement ? STATEMENT_HEADERS : ACCOUNTING_HEADERS
  end

  private
  def broadcast_row_append
    Turbo::StreamsChannel.broadcast_prepend_later_to(
      :report_files,
      target: "report_files_list",
      partial: "report_files/file_row",
      locals: { file: self }
    )
  end

  def broadcast_status_refresh
    reload
    status_dom_id = dom_id(self, :status)

    Turbo::StreamsChannel.broadcast_update_later_to(
      :report_files,
      target: status_dom_id,
      partial: "report_files/status_badge",
      locals: { file: self }
    )

    Turbo::StreamsChannel.broadcast_update_later_to(
      self,
      target: status_dom_id,
      partial: "report_files/status_badge",
      locals: { file: self }
    )
  end

  def set_defaults
    self.status ||= :pending
    self.reported_on ||= Date.current
  end
end
