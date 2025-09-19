# frozen_string_literal: true
# Usage:
#   bin/rails runner script/diagnose_sources.rb > sources_diagnose.log
#
# What it does:
# - Detects models/tables for: ReportFile, StatementLine, AccountingEntry, AdyenPayout (optional)
# - Prints columns (name/type/null/default), key indexes, and safe sample rows
# - Detects likely date/currency/amount/category columns & foreign keys
# - Emits a JSON "capabilities" section ChatGPT can use to wire Sources::* precisely

require "json"
require "active_support"
require "active_support/core_ext/string/inflections"

TARGETS = %w[ReportFile StatementLine AccountingEntry AdyenPayout].freeze

def say(title)
  puts "\n=== #{title} ==="
end

def sanitize_value(v)
  case v
  when String
    v.length > 120 ? v[0,117] + "..." : v
  when BigDecimal
    v.to_s("F")
  else
    v
  end
end

def sample_rows(model, limit: 5, only: nil)
  rel = model.limit(limit)
  rel = rel.select(only) if only
  rel.map do |row|
    (only || row.attributes.keys).each_with_object({}) do |k, h|
      h[k] = sanitize_value(row[k])
    end
  end
end

def index_summary(connection, table)
  connection.indexes(table).map do |idx|
    {
      name: idx.name,
      unique: idx.unique,
      columns: idx.columns
    }
  end
end

def guess_columns(cols)
  names = cols.map(&:name).map(&:to_s)
  {
    id: (names & %w[id]).first,
    fk_report_file_id: (names & %w[report_file_id file_id report_id]).first,
    occurred_on: (names & %w[occurred_on occurred_at date business_date booking_date]).first,
    currency: (names & %w[currency currency_code]).first,
    amount_cents: (names & %w[amount_cents net_cents value_cents amount_minor total_cents]).first,
    amount_decimal: (names & %w[amount net value total]).first,
    category: (names & %w[category type subtype entry_type txn_type]).first,
    account_scope: (names & %w[account_scope merchant_account platform_account entity scope]).first,
    kind: (names & %w[kind report_kind type]).first,
    reported_on: (names & %w[reported_on report_date as_of_date]).first
  }
end

env = Rails.env
rails_ver = Rails.version
adapter = ActiveRecord::Base.connection_db_config.adapter

puts "### Sources Diagnose"
puts "environment: #{env}"
puts "rails_version: #{rails_ver}"
puts "db_adapter: #{adapter}"

connection = ActiveRecord::Base.connection

all = {}

TARGETS.each do |const_name|
  say(const_name)
  model = const_name.safe_constantize
  unless model
    puts "model_defined: false"
    next
  end
  table = model.table_name
  puts "model_defined: true"
  puts "table: #{table}"

  cols = connection.columns(table)
  puts "columns (name:type:null:default):"
  cols.each do |c|
    default_s = c.default.is_a?(String) && c.default.size > 40 ? c.default[0,37] + "..." : c.default
    puts "  - #{c.name}: #{c.sql_type} : #{c.null} : #{default_s.inspect}"
  end

  puts "indexes:"
  idxs = index_summary(connection, table)
  if idxs.empty?
    puts "  (none)"
  else
    idxs.each { |i| puts "  - #{i[:name]} #{i[:unique] ? '[UNIQUE]' : ''} -> (#{i[:columns].join(', ')})" }
  end

  guesses = guess_columns(cols)
  puts "guessed_columns:"
  guesses.each { |k,v| puts "  #{k}: #{v.inspect}" }

  # Choose safe columns to display in sample rows
  safe_cols = [
    guesses[:id], guesses[:fk_report_file_id],
    guesses[:occurred_on], guesses[:reported_on],
    guesses[:currency], guesses[:amount_cents], guesses[:amount_decimal],
    guesses[:category], guesses[:account_scope], guesses[:kind], "created_at", "updated_at"
  ].compact.uniq

  begin
    rows = sample_rows(model, limit: 5, only: safe_cols)
    puts "sample_rows (#{rows.size}):"
    rows.each_with_index do |r, i|
      puts "  #{i+1}. #{r.to_json}"
    end
  rescue => e
    puts "sample_rows_error: #{e.class}: #{e.message}"
  end

  # Small distinct summaries
  begin
    if guesses[:kind]
      kinds = model.distinct.order(guesses[:kind]).limit(15).pluck(guesses[:kind])
      puts "distinct_kinds(<=15): #{kinds.inspect}"
    end
  rescue => e
    puts "distinct_kinds_error: #{e.message}"
  end

  begin
    if guesses[:category]
      cats = model.distinct.order(guesses[:category]).limit(15).pluck(guesses[:category])
      puts "distinct_categories(<=15): #{cats.inspect}"
    end
  rescue => e
    puts "distinct_categories_error: #{e.message}"
  end

  all[const_name] = {
    table: table,
    columns: cols.map { |c| { name: c.name, type: c.sql_type, null: c.null, default: c.default } },
    indexes: idxs,
    guesses: guesses
  }
end

# Relationship sanity: link StatementLine/AccountingEntry -> ReportFile
say("Relationships sanity")
begin
  rf = "ReportFile".safe_constantize
  sl = "StatementLine".safe_constantize
  ae = "AccountingEntry".safe_constantize

  if sl && rf
    fk = all.dig("StatementLine", :guesses, :fk_report_file_id)
    puts "StatementLine -> ReportFile FK: #{fk.inspect}"
    if fk
      orphan_count = sl.where("#{fk} IS NOT NULL").where.not("#{fk} IN (?)", rf.select(:id)).count
      puts "  orphans_with_fk_set: #{orphan_count}"
    end
  end

  if ae && rf
    fk = all.dig("AccountingEntry", :guesses, :fk_report_file_id)
    puts "AccountingEntry -> ReportFile FK: #{fk.inspect}"
    if fk
      orphan_count = ae.where("#{fk} IS NOT NULL").where.not("#{fk} IN (?)", rf.select(:id)).count
      puts "  orphans_with_fk_set: #{orphan_count}"
    end
  end
rescue => e
  puts "relationship_check_error: #{e.class}: #{e.message}"
end

# Emit a machine-friendly JSON block at the end for ChatGPT
say("Capabilities JSON")
cap = {
  environment: env,
  rails_version: rails_ver,
  db_adapter: adapter,
  targets: all
}
puts cap.to_json
