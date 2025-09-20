# app/controllers/reconciliations_controller.rb
class ReconciliationsController < ApplicationController
  include ApplicationHelper

  def index
    @currency  = params[:currency].presence
    @date_from = (params[:from].presence && Date.parse(params[:from])) rescue nil
    @date_to   = (params[:to].presence   && Date.parse(params[:to]))   rescue nil

    @days  = ReconciliationDay.order(date: :desc)

    if params.key?(:scope)
      @scope = params[:scope].presence
      @days  = @days.where(account_scope: @scope)
    else
      # default to nil-scope unless scope is explicitly provided
      @scope = nil
      @days  = @days.where(account_scope: nil)
    end

    @days = @days.where(currency: @currency) if @currency.present?

    if @date_from && @date_to
      @days = @days.where(date: @date_from..@date_to)
    else
      @days = @days.where(account_scope: nil).where("date >= ?", 30.days.ago.to_date) unless params.key?(:scope)
    end
    @days = @days.limit(60)

    if @days.any?
      scopes     = @days.map(&:account_scope).uniq
      dates      = @days.map(&:date).uniq
      currencies = @days.map(&:currency).uniq

      @payout_lookup = PayoutMatch
                        .where(account_scope: scopes, payout_date: dates, currency: currencies)
                        .each_with_object({}) do |payout, memo|
        key = [payout.account_scope, payout.payout_date, payout.currency]
        memo[key] = true
      end
    else
      @payout_lookup = {}
    end

    # dropdown data
    @available_scopes_nonnil = ReconciliationDay.distinct.where.not(account_scope: nil)
                                                .order(:account_scope).pluck(:account_scope)
    @available_currencies     = ReconciliationDay.distinct.order(:currency).pluck(:currency)
  end

  # app/controllers/reconciliations_controller.rb
  def by_key
    date     = Date.parse(params[:date])
    currency = params[:currency]
    scope    = params[:scope].presence

    @day = ReconciliationDay.find_by!(account_scope: scope, date:, currency:)
    @vars    = @day.reconciliation_variances
    @fees    = FeeBreakdown.find_by(account_scope: @day.account_scope, date: @day.date, currency: @day.currency)
    @payouts = PayoutMatch.where(account_scope: @day.account_scope, payout_date: @day.date, currency: @day.currency)

    # neighbors for same scope/currency
    series = ReconciliationDay.where(account_scope: scope, currency: currency).order(:date).pluck(:date)
    idx = series.index(date)
    @prev_date = series[idx - 1] if idx && idx.positive?
    @next_date = series[idx + 1] if idx && idx < series.length - 1

    render :show
  rescue ArgumentError, ActiveRecord::RecordNotFound
    redirect_to reconciliations_path, alert: "Reconciliation not found for #{params[:date]} #{currency}."
  end


  # POST /reconciliations/run
  def run
    scope    = params[:scope].presence
    currency = params[:currency].presence || "USD"
    from     = Date.parse(params[:from]) rescue nil
    to       = Date.parse(params[:to])   rescue nil

    (from..to).each do |d|
      Recon::BuildDaily.new(account_scope: scope, date: d, currency: currency).call
    end

    redirect_to reconciliations_path(
                  scope: scope, currency: currency, from: params[:from], to: params[:to]
                ),
                notice: "Rebuilt #{from}..#{to} for #{currency}#{scope ? " (#{scope})" : ""}"
  end

  def show
    @day = ReconciliationDay.find(params[:id])
    @vars    = @day.reconciliation_variances
    @fees    = FeeBreakdown.find_by(account_scope: @day.account_scope, date: @day.date, currency: @day.currency)
    @payouts = PayoutMatch.where(account_scope: @day.account_scope, payout_date: @day.date, currency: @day.currency)
  rescue ActiveRecord::RecordNotFound
    redirect_to reconciliations_path, alert: "That reconciliation was rebuilt or removed. Please open it again from the list."
  end
end
