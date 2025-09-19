# frozen_string_literal: true
require_relative "config"
require_relative "helpers"

module Sources
  class Fees
    include Config
    extend Helpers

    # With current samples, there are no obvious "fee" rows yet.
    # We return zeros (and you’ll see "No fee data" or all 0 in the UI).
    # Once fee categories start appearing, wire rules below (match on category/type substrings).
    def self.for(scope, date, currency)
      {
        scheme: 0,
        processing: 0,
        interchange: 0,
        chargeback: 0,
        payout: 0,
        other: 0
      }
    end
  end
end
