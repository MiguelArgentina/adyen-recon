class CreateDailySummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_summaries do |t|
      t.date :day
      t.string :currency
      t.bigint :gross_revenue_minor
      t.bigint :refunds_minor
      t.bigint :chargebacks_minor
      t.bigint :fees_minor
      t.bigint :payout_fees_minor
      t.bigint :net_revenue_minor
      t.bigint :closing_balance_minor
      t.string :account_code
      t.string :account_id
      t.references :report_file, null: false, foreign_key: true

      t.timestamps
    end
  end
end
