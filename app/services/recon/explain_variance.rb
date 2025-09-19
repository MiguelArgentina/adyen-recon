module Recon
  class ExplainVariance
    def initialize(day) = @day = day

    def call
      @day.reconciliation_variances.delete_all

      # examples – replace stubs with actual diffs
      if @day.statement_total_cents.nil?
        add(:missing_statement, 0, note: "No statement imported for the day")
      end

      if (fx = fx_delta_abs) && fx > 0
        add(:fx_mismatch, fx, rate: applied_rate, note: "Accounting vs Statement currency conversion delta")
      end

      if (round = rounding_delta_abs) && round > 0 && round <= 50
        add(:rounding, round, note: "Rounding under 0.50")
      end
    end

    private

    def add(kind, amount_cents, payload = {})
      @day.reconciliation_variances.create!(kind:, amount_cents:, payload:)
    end

    # --- replace with your real logic ---
    def fx_delta_abs = 0
    def applied_rate = nil
    def rounding_delta_abs = (@day.computed_total_cents.to_i - @day.statement_total_cents.to_i).abs
  end
end