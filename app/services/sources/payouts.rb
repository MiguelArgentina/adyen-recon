# frozen_string_literal: true
require_relative "config"

module Sources
  class Payouts
    include Config

    def self.for(scope)
      return [] unless Config::AdyenPayout
      # If/when you add a payouts table, fill this in accordingly.
      []
    end
  end
end
