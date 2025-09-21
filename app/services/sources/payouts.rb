# frozen_string_literal: true
require_relative "config"

module Sources
  class Payouts
    include Config

    def self.for(scope, date: nil, currency: nil)
      model = Config::PayoutModel
      return [] unless model

      relation = model.left_joins(:source_report_file)

      account_code, account_holder = Sources::ScopeKey.parse(scope)
      if account_code.nil? && account_holder.nil?
        relation = relation.where("COALESCE(report_files.account_code, '') = ''")
                             .where("COALESCE(report_files.account_id, '') = ''")
      else
        relation = relation.where("report_files.account_code = ?", account_code) if account_code
        relation = relation.where("report_files.account_id = ?", account_holder) if account_holder
      end

      relation = relation.where(booked_on: date) if date
      if currency.present?
        relation = relation.where("COALESCE(payouts.currency, report_files.currency) = ?", currency)
      end

      relation.find_each.map do |p|
        resolved_currency = p.currency.presence || p.source_report_file&.currency
        {
          id: p.bank_transfer_id.presence || p.payout_ref.presence || "payout-#{p.id}",
          date: p.booked_on,
          currency: resolved_currency,
          amount_cents: p.amount_minor.to_i,
          ref: p.payout_ref
        }
      end
    end
  end
end
