# app/services/summarize/build_daily_summaries.rb
module Summarize
  class BuildDailySummaries
    # Lowercase canonical identifiers
    CAPTURE_TYPES        = %w[capture].freeze
    CAPTURE_CATEGORIES   = %w[payment platformpayment].freeze
    REFUND_TYPES         = %w[refund paymentrefund refundcorrection].freeze
    CHARGEBACK_TYPES     = %w[chargeback dispute].freeze
    FEE_TYPES            = %w[fee paymentcost invoicededuction cashoutfee platformfee processingfee commission].freeze
    PAYOUT_FEE_TYPES     = %w[cashoutfee payoutfee].freeze
    TRANSFER_FEE_TYPES   = %w[internaltransfer banktransfer].freeze

    def self.call(day:)
      currencies = (AccountingEntry.where(book_date: day).distinct.pluck(:currency) +
                    StatementLine.where(book_date: day).distinct.pluck(:currency)).compact.uniq
      currencies = ["USD"] if currencies.empty?
      currencies.each { |cur| build_for_currency(day, cur) }
    end

    def self.build_for_currency(day, currency)
      entries = AccountingEntry.where(book_date: day, currency: currency)
                               .select(:id, :report_file_id, :category, :type, :amount_minor)
      stmt_scope = StatementLine.where(book_date: day, currency: currency).select(:id,:report_file_id,:balance_after_minor)

      if entries.empty? && stmt_scope.where.not(balance_after_minor: nil).blank?
        Rails.logger.debug("[DailySummary] skip day=#{day} currency=#{currency} (no entries & no closing balance)")
        return
      end

      gross = refunds = chargebacks = fees = payout_fees = 0
      capture_count = refund_count = chargeback_count = fee_count = payout_fee_count = 0

      # Determine a representative report_file_id (prefer accounting entry file)
      candidate_report_file_id = entries.first&.report_file_id || stmt_scope.first&.report_file_id
      unless candidate_report_file_id
        Rails.logger.warn("[DailySummary] abort day=#{day} currency=#{currency} no candidate report_file_id found")
        return
      end

      entries.each do |e|
        cat = (e.category || '').downcase
        typ = (e.type || '').downcase
        amt = e.amount_minor.to_i

        if CAPTURE_TYPES.include?(typ) && CAPTURE_CATEGORIES.include?(cat)
          if amt >= 0
            gross += amt; capture_count += 1
          else
            refunds += amt.abs; refund_count += 1
          end
        elsif REFUND_TYPES.include?(typ) || cat == 'refund'
          refunds += amt.abs; refund_count += 1
        elsif CHARGEBACK_TYPES.include?(typ) || cat == 'chargeback'
          chargebacks += amt.abs; chargeback_count += 1
        elsif PAYOUT_FEE_TYPES.include?(typ) || PAYOUT_FEE_TYPES.include?(cat)
          payout_fees += amt.abs; payout_fee_count += 1
        elsif FEE_TYPES.include?(typ) || FEE_TYPES.include?(cat) || TRANSFER_FEE_TYPES.include?(typ) || TRANSFER_FEE_TYPES.include?(cat)
          fees += amt.abs; fee_count += 1
        end
      end

      closing = stmt_scope.where.not(balance_after_minor: nil).order(:id).last&.balance_after_minor

      if [gross, refunds, chargebacks, fees, payout_fees, closing].all? { |v| v.to_i == 0 }
        Rails.logger.info("[DailySummary] skip empty metrics day=#{day} currency=#{currency} (captures=#{capture_count} fees=#{fee_count})")
        return
      end

      net = gross - refunds - chargebacks - fees
      ds = DailySummary.where(day: day, currency: currency).order(:id).first || DailySummary.new(day: day, currency: currency, report_file_id: candidate_report_file_id)
      ds.report_file_id ||= candidate_report_file_id
      ds.gross_revenue_minor = gross
      ds.refunds_minor = refunds
      ds.chargebacks_minor = chargebacks
      ds.fees_minor = fees
      ds.payout_fees_minor = payout_fees
      ds.net_revenue_minor = net
      ds.closing_balance_minor = closing
      ds.account_code ||= nil
      ds.account_id ||= nil
      ds.save!
      Rails.logger.info("[DailySummary] upsert day=#{day} currency=#{currency} rf=#{candidate_report_file_id} gross=#{gross} refunds=#{refunds} chargebacks=#{chargebacks} fees=#{fees} payout_fees=#{payout_fees} net=#{net} closing=#{closing} captures=#{capture_count} fee_rows=#{fee_count}")
    rescue => e
      Rails.logger.error("[DailySummary] failure day=#{day} currency=#{currency} err=#{e.class}: #{e.message}")
      raise
    end
  end
end
