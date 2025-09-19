# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
MappingProfile.find_or_create_by!(name: "Default") do |p|
  p.revenue_gl = "4000"
  p.refunds_gl = "4050"
  p.chargebacks_gl = "4060"
  p.fees_gl = "6200"
  p.payout_fees_gl = "6201"
  p.cash_account_gl = "1010"
  p.clearing_account_gl = "1100"
end