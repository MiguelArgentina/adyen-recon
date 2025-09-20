# frozen_string_literal: true
module Sources
  module Config
    # AR models
    ReportFile       = "ReportFile".safe_constantize
    StatementLine    = "StatementLine".safe_constantize
    AccountingEntry  = "AccountingEntry".safe_constantize
    PayoutModel      = "Payout".safe_constantize

    # ReportFile columns
    RF_KIND        = "kind"         # enum int ("statement"/"accounting")
    RF_REPORTED_ON = "reported_on"  # Date
    RF_CURRENCY    = "currency"     # may be blank in some files
    RF_SCOPE       = "account_code" # you’re using account_code as the scope

    # StatementLine columns
    SL_FILE_ID   = "report_file_id"
    SL_DATE      = "occurred_on"    # kept for reference
    SL_BOOK_DATE = "book_date"      # <-- use this for daily totals
    SL_CURRENCY  = "currency"
    SL_AMOUNT    = "amount_minor"
    SL_CATEGORY  = "category"
    SL_TYPE      = "type"

    # AccountingEntry columns
    AE_FILE_ID   = "report_file_id"
    AE_DATE      = "occurred_on"    # kept for reference
    AE_BOOK_DATE = "book_date"      # <-- use this for daily totals
    AE_CURRENCY  = "currency"
    AE_AMOUNT    = "amount_minor"
    AE_CATEGORY  = "category"
    AE_TYPE      = "type"

    # Enum names (Ruby-level). We'll resolve to integers safely.
    KIND_STATEMENT  = "statement"
    KIND_ACCOUNTING = "accounting"
  end
end
