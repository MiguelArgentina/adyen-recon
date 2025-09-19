# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_19_012406) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounting_entries", force: :cascade do |t|
    t.bigint "report_file_id", null: false
    t.integer "line_no"
    t.date "occurred_on"
    t.date "book_date"
    t.string "direction"
    t.string "category"
    t.string "type"
    t.string "subcategory"
    t.string "status"
    t.bigint "amount_minor"
    t.string "currency"
    t.string "balance_account_id"
    t.string "balance_account_code"
    t.string "psp_reference"
    t.string "transfer_id"
    t.string "payout_id"
    t.string "reference"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_date", "category", "type", "transfer_id", "payout_id"], name: "idx_on_book_date_category_type_transfer_id_payout_i_10c693b29d"
    t.index ["report_file_id"], name: "index_accounting_entries_on_report_file_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "adyen_credentials", force: :cascade do |t|
    t.string "label"
    t.string "sftp_host"
    t.string "sftp_username"
    t.integer "sftp_port"
    t.integer "auth_method"
    t.text "encrypted_private_key"
    t.text "encrypted_passphrase"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "daily_summaries", force: :cascade do |t|
    t.date "day"
    t.string "currency"
    t.bigint "gross_revenue_minor"
    t.bigint "refunds_minor"
    t.bigint "chargebacks_minor"
    t.bigint "fees_minor"
    t.bigint "payout_fees_minor"
    t.bigint "net_revenue_minor"
    t.bigint "closing_balance_minor"
    t.string "account_code"
    t.string "account_id"
    t.bigint "report_file_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_file_id"], name: "index_daily_summaries_on_report_file_id"
  end

  create_table "export_files", force: :cascade do |t|
    t.integer "kind"
    t.integer "status"
    t.bigint "mapping_profile_id", null: false
    t.date "period_start"
    t.date "period_end"
    t.string "file_path"
    t.bigint "bytes"
    t.string "checksum"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mapping_profile_id"], name: "index_export_files_on_mapping_profile_id"
  end

  create_table "fee_breakdowns", force: :cascade do |t|
    t.string "account_scope", null: false
    t.date "date", null: false
    t.string "currency", null: false
    t.bigint "scheme_fees_cents", default: 0
    t.bigint "processing_fees_cents", default: 0
    t.bigint "interchange_cents", default: 0
    t.bigint "chargeback_fees_cents", default: 0
    t.bigint "payout_fees_cents", default: 0
    t.bigint "other_fees_cents", default: 0
    t.bigint "total_fees_cents", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_scope", "date", "currency"], name: "idx_fee_breakdowns_scope_date_curr_unique", unique: true
  end

  create_table "mapping_profiles", force: :cascade do |t|
    t.string "name"
    t.string "revenue_gl"
    t.string "refunds_gl"
    t.string "chargebacks_gl"
    t.string "fees_gl"
    t.string "payout_fees_gl"
    t.string "cash_account_gl"
    t.string "clearing_account_gl"
    t.jsonb "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payout_matches", force: :cascade do |t|
    t.string "account_scope"
    t.date "payout_date"
    t.string "currency"
    t.string "adyen_payout_id"
    t.bigint "adyen_amount_cents"
    t.string "bank_ref"
    t.bigint "bank_amount_cents"
    t.integer "status"
    t.jsonb "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payouts", force: :cascade do |t|
    t.string "bank_transfer_id"
    t.string "payout_ref"
    t.date "booked_on"
    t.string "currency"
    t.bigint "amount_minor"
    t.bigint "fee_minor"
    t.string "status"
    t.bigint "source_report_file_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_report_file_id"], name: "index_payouts_on_source_report_file_id"
  end

  create_table "reconciliation_days", force: :cascade do |t|
    t.string "account_scope"
    t.date "date", null: false
    t.string "currency", null: false
    t.bigint "statement_total_cents"
    t.bigint "accounting_total_cents"
    t.bigint "computed_total_cents"
    t.bigint "variance_cents"
    t.integer "status", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_scope", "date", "currency"], name: "idx_recon_days_scope_date_curr_unique", unique: true
    t.index ["account_scope", "date", "currency"], name: "idx_recon_days_scope_date_currency_unique", unique: true
    t.index ["date"], name: "index_reconciliation_days_on_date"
  end

  create_table "reconciliation_variances", force: :cascade do |t|
    t.bigint "reconciliation_day_id", null: false
    t.integer "kind", default: 9, null: false
    t.bigint "amount_cents", default: 0, null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_reconciliation_variances_on_kind"
    t.index ["reconciliation_day_id"], name: "index_reconciliation_variances_on_reconciliation_day_id"
  end

  create_table "report_files", force: :cascade do |t|
    t.integer "kind"
    t.integer "status"
    t.date "reported_on"
    t.string "account_code"
    t.string "account_id"
    t.string "currency"
    t.string "original_filename"
    t.bigint "bytes"
    t.string "checksum"
    t.text "error"
    t.bigint "adyen_credential_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "settings", default: {}, null: false
    t.index ["adyen_credential_id"], name: "index_report_files_on_adyen_credential_id"
    t.index ["kind", "status", "reported_on"], name: "index_report_files_on_kind_and_status_and_reported_on"
    t.index ["settings"], name: "index_report_files_on_settings", using: :gin
  end

  create_table "statement_lines", force: :cascade do |t|
    t.bigint "report_file_id", null: false
    t.integer "line_no"
    t.date "occurred_on"
    t.date "book_date"
    t.string "category"
    t.string "type"
    t.string "status"
    t.bigint "amount_minor"
    t.string "currency"
    t.bigint "balance_before_minor"
    t.bigint "balance_after_minor"
    t.string "balance_account_id"
    t.string "balance_account_code"
    t.string "reference"
    t.string "transfer_id"
    t.string "payout_id"
    t.string "description"
    t.string "counterparty"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_date", "category", "type", "payout_id", "transfer_id"], name: "idx_on_book_date_category_type_payout_id_transfer_i_feb235ad80"
    t.index ["report_file_id"], name: "index_statement_lines_on_report_file_id"
  end

  add_foreign_key "accounting_entries", "report_files"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "daily_summaries", "report_files"
  add_foreign_key "export_files", "mapping_profiles"
  add_foreign_key "payouts", "report_files", column: "source_report_file_id"
  add_foreign_key "reconciliation_variances", "reconciliation_days"
  add_foreign_key "report_files", "adyen_credentials"
  add_foreign_key "statement_lines", "report_files"
end
