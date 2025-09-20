# app/jobs/reconcile_day_job.rb
class ReconcileDayJob < ApplicationJob
  queue_as :default

  def perform(account_scope:, date:, currency:)
    day = Recon::BuildDaily.new(account_scope:, date:, currency:).call
    Recon::FeeIntel.new(account_scope:, date:, currency:).call
    begin
      Recon::PayoutMatcher.new(account_scope:, bank_lines: [], date:, currency:).call
    rescue => e
      Rails.logger.warn("[ReconcileDayJob] payout matcher failed scope=#{account_scope.inspect} date=#{date} currency=#{currency}: #{e.class}: #{e.message}")
    end
    Turbo::StreamsChannel.broadcast_replace_to(
      "recon", target: "recon_day_#{day.id}",
      partial: "reconciliations/day_row", locals: { day: }
    )
  end
end
