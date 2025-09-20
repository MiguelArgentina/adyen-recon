# frozen_string_literal: true
require_relative "config"
require_relative "helpers"

module Sources
  class Fees
    include Config
    extend Helpers

    def self.for(scope, date, currency)
      return EMPTY.dup unless Config::AccountingEntry && Config::ReportFile

      rf_kind = ReportFile.kinds[Config::KIND_ACCOUNTING]

      base = Config::AccountingEntry
               .joins("INNER JOIN report_files rf ON rf.id = accounting_entries.#{Config::AE_FILE_ID}")
               .where("rf.#{Config::RF_KIND} = ?", rf_kind)
               .yield_self do |rel|
                 if scope.nil?
                   rel.where("rf.#{Config::RF_SCOPE} IS NULL")
                 else
                   rel.where("rf.#{Config::RF_SCOPE} = ?", scope)
                 end
               end
               .where("accounting_entries.#{Config::AE_BOOK_DATE} = ?", date)
               .where(<<~SQL, currency, currency)
                 (accounting_entries.#{Config::AE_CURRENCY} = ?
                   OR (accounting_entries.#{Config::AE_CURRENCY} IS NULL OR accounting_entries.#{Config::AE_CURRENCY} = '')
                      AND rf.#{Config::RF_CURRENCY} = ?)
               SQL
               .where.not("accounting_entries.#{Config::AE_AMOUNT} IS NULL")

      totals = EMPTY.dup

      base.pluck(
        "accounting_entries.#{Config::AE_AMOUNT}",
        "accounting_entries.#{Config::AE_CATEGORY}",
        "accounting_entries.#{Config::AE_TYPE}",
        "accounting_entries.#{Config::AE_SUBCATEGORY}",
        "accounting_entries.#{Config::AE_REFERENCE}",
        "accounting_entries.#{Config::AE_DESCRIPTION}"
      ).each do |amount, category, type, subcategory, reference, description|
        next if amount.nil?

        bucket = bucket_for(category, type, subcategory, reference, description)
        next unless bucket

        totals[bucket] += amount.to_i
      end

      totals
    end

    EMPTY = {
      scheme: 0,
      processing: 0,
      interchange: 0,
      chargeback: 0,
      payout: 0,
      other: 0
    }.freeze

    private_constant :EMPTY

    def self.bucket_for(category, type, subcategory, reference, description)
      values = [category, type, subcategory, reference, description].compact
      values.reject! { |v| v.to_s.strip.empty? }
      return nil if values.empty?

      raw = values.map { |v| v.to_s.downcase }.join(" ")
      normalized = raw.gsub(/[^a-z0-9]+/, " ")
      haystack = "#{raw} #{normalized}".squeeze(" ")

      return :chargeback if chargeback_fee?(haystack, category)
      return :interchange if haystack.include?("interchange")
      return :scheme if scheme_fee?(haystack)
      return :processing if processing_fee?(haystack)
      return :payout if payout_fee?(haystack, category)
      return :other if other_fee?(haystack)

      nil
    end

    private_class_method :bucket_for

    private_class_method def self.chargeback_fee?(haystack, category)
      (haystack.include?("chargeback") && (haystack.include?("fee") || haystack.include?("cost") || haystack.include?("commission") || haystack.include?("penalty"))) ||
        (category.to_s == "chargeback" && (haystack.include?("fee") || haystack.include?("cost") || haystack.include?("commission")))
    end

    private_class_method def self.scheme_fee?(haystack)
      haystack.include?("scheme fee") ||
        haystack.include?("schemefee") ||
        haystack.include?("network fee") ||
        haystack.include?("assessment")
    end

    private_class_method def self.processing_fee?(haystack)
      haystack.include?("processing fee") ||
        haystack.include?("processingfee") ||
        haystack.include?("psp fee") ||
        haystack.include?("pspfee") ||
        haystack.include?("commission") ||
        haystack.include?("markup") ||
        haystack.include?("mark up") ||
        haystack.include?("mark-up") ||
        haystack.include?("payment fee") ||
        haystack.include?("platform fee") ||
        haystack.include?("service fee") ||
        haystack.include?("gateway fee") ||
        haystack.include?("transaction fee") ||
        haystack.include?("acquirer fee")
    end

    private_class_method def self.payout_fee?(haystack, category)
      haystack.include?("payout fee") ||
        haystack.include?("payoutfee") ||
        haystack.include?("payout cost") ||
        haystack.include?("cashout fee") ||
        haystack.include?("withdrawal fee") ||
        haystack.include?("bank transfer fee") ||
        haystack.include?("banktransferfee") ||
        haystack.include?("sepa fee") ||
        haystack.include?("swift fee") ||
        (category.to_s == "bank" && haystack.include?("fee"))
    end

    private_class_method def self.other_fee?(haystack)
      haystack.include?("fee") || haystack.include?("cost") || haystack.include?("levy") || haystack.include?("assessment")
    end
  end
end
