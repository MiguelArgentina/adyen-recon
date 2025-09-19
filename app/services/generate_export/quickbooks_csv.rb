# app/services/generate_export/quickbooks_csv.rb
require "csv"
module GenerateExport
  class QuickbooksCsv
    HEADER = %w[Date RefNumber Account Debit Credit Memo Name].freeze

    def self.call(profile:, period_start:, period_end:)
      raw = DailySummary.where(day: period_start..period_end)
                        .select(:day,:gross_revenue_minor,:refunds_minor,:chargebacks_minor,:fees_minor,:payout_fees_minor)
      grouped = raw.group_by(&:day).transform_values do |arr|
        arr.reduce({gross:0, refunds:0, chargebacks:0, fees:0, payout:0}) do |h,ds|
          h[:gross]       += ds.gross_revenue_minor.to_i
          h[:refunds]     += ds.refunds_minor.to_i
          h[:chargebacks] += ds.chargebacks_minor.to_i
          h[:fees]        += ds.fees_minor.to_i
          h[:payout]      += ds.payout_fees_minor.to_i
          h
        end
      end

      CSV.generate(headers: true) do |csv|
        csv << HEADER
        grouped.sort_by { |day,_| day }.each do |day, sums|
          total_activity = sums.values.sum
          next if total_activity == 0 # skip purely empty day
          ref = "ADYEN-#{day}"
          # Revenue (gross) row
          csv << [day, ref, profile.revenue_gl, decimal(sums[:gross]), nil, "Adyen sales", nil] if sums[:gross] > 0
          # Refunds
            csv << [day, ref, profile.refunds_gl, nil, decimal(sums[:refunds]), "Adyen refunds", nil] if sums[:refunds] > 0
          # Chargebacks
            csv << [day, ref, profile.chargebacks_gl, nil, decimal(sums[:chargebacks]), "Adyen chargebacks", nil] if sums[:chargebacks] > 0
          # Fees
            csv << [day, ref, profile.fees_gl, nil, decimal(sums[:fees]), "Adyen fees", nil] if sums[:fees] > 0
          # Payout Fees
            csv << [day, ref, profile.payout_fees_gl, nil, decimal(sums[:payout]), "Adyen payout fees", nil] if sums[:payout] > 0
        end
      end
    end

    def self.decimal(minor) = (minor.to_i / 100.0).round(2)
  end
end
