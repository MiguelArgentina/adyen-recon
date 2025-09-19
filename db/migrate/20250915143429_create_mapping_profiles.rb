class CreateMappingProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :mapping_profiles do |t|
      t.string :name
      t.string :revenue_gl
      t.string :refunds_gl
      t.string :chargebacks_gl
      t.string :fees_gl
      t.string :payout_fees_gl
      t.string :cash_account_gl
      t.string :clearing_account_gl
      t.jsonb :settings

      t.timestamps
    end
  end
end
