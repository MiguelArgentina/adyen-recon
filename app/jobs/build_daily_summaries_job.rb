# app/jobs/build_daily_summaries_job.rb
class BuildDailySummariesJob < ApplicationJob
  queue_as :default
  def perform(day = Date.yesterday)
    Summarize::BuildDailySummaries.call(day:)
  end
end