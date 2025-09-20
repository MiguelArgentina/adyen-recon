# app/services/reconcile/payouts_from_statements.rb
module Reconcile
  class PayoutsFromStatements
    # Rule of thumb: category='bank', type='banktransfer', status in {booked, received}
    SUPPORTED_STATUSES = %w[booked received].freeze

    def self.call(report_file:)
      lines = report_file.statement_lines
                         .where(category: "bank", type: "banktransfer")
                         .where("LOWER(COALESCE(statement_lines.status, '')) IN (?)", SUPPORTED_STATUSES)
      lines.find_each do |l|
        Payout.find_or_create_by!(bank_transfer_id: l.transfer_id.presence || l.reference) do |p|
          p.source_report_file_id = report_file.id
          p.booked_on   = l.book_date || l.occurred_on
          p.currency    = l.currency
          p.amount_minor = l.amount_minor
          p.status      = l.status
          p.payout_ref  = l.payout_id.presence || l.reference
          p.fee_minor   = 0 # fill via Accounting fee sum below
        end
      end
    end
  end
end
