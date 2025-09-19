# frozen_string_literal: true
require "csv"

module GenerateExport
  # Exports DailySummary rows as Xero "Manual Journal" style CSV
  # Columns: Date, Reference, Description, AccountCode, TaxType, Debit, Credit, TrackingName1, TrackingOption1, TrackingName2, TrackingOption2
  #
  # Notes:
  # - Uses account *codes* from MappingProfile (e.g., "200", "4000", etc.).
  # - Balances each day with an offset to the clearing account.
  # - Amounts are converted from minor units (integer cents) to decimals.
  class XeroCsv
    HEADER = %w[
      Date Reference Description AccountCode TaxType Debit Credit
      TrackingName1 TrackingOption1 TrackingName2 TrackingOption2
    ].freeze

    DEFAULT_TAX = "NONE" # change if you need a different TaxType

    def self.call(profile:, period_start:, period_end:, tracking: {})
      rows = DailySummary.where(day: period_start..period_end).order(:day)
      CSV.generate(headers: true) do |csv|
        csv << HEADER

        rows.each do |d|
          ref = "ADYEN-#{d.day}"

          gross        = d.gross_revenue_minor.to_i
          refunds      = d.refunds_minor.to_i
          chargebacks  = d.chargebacks_minor.to_i
          fees         = d.fees_minor.to_i
          payout_fees  = d.payout_fees_minor.to_i

          # Net cash movement to balance with clearing account
          net_cash = gross - refunds - chargebacks - fees - payout_fees

          # Credit revenue
          write_line(csv, d.day, ref, "Adyen sales",        profile.revenue_gl,        0,            gross,        tracking:)
          # Debits (refunds, chargebacks, fees)
          write_line(csv, d.day, ref, "Adyen refunds",      profile.refunds_gl,        refunds,      0,            tracking:)      if refunds.positive?
          write_line(csv, d.day, ref, "Adyen chargebacks",  profile.chargebacks_gl,    chargebacks,  0,            tracking:)      if chargebacks.positive?
          write_line(csv, d.day, ref, "Adyen fees",         profile.fees_gl,           fees,         0,            tracking:)      if fees.positive?
          write_line(csv, d.day, ref, "Adyen payout fees",  profile.payout_fees_gl,    payout_fees,  0,            tracking:)      if payout_fees.positive?

          # Clearing offset to make the journal balance
          if net_cash >= 0
            write_line(csv, d.day, ref, "Adyen net cash to clearing",   profile.clearing_account_gl, net_cash, 0, tracking:)
          else
            write_line(csv, d.day, ref, "Adyen net cash from clearing", profile.clearing_account_gl, 0,       -net_cash, tracking:)
          end
        end
      end
    end

    def self.write_line(csv, date, ref, desc, account_code, debit_minor, credit_minor, tracking: {}, tax_type: DEFAULT_TAX)
      csv << [
        date,
        ref,
        desc,
        account_code,
        tax_type,
        decimal(debit_minor),
        decimal(credit_minor),
        tracking[:name1],
        tracking[:option1],
        tracking[:name2],
        tracking[:option2]
      ]
    end

    def self.decimal(minor)
      return nil if minor.nil?
      (minor.to_i / 100.0).round(2)
    end
  end
end
