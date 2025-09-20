# frozen_string_literal: true
module Sources
  class Computed
    C = Config

    def self.total_for(scope, date, currency)
      return Sources::Accounting.total_for(scope, date, currency) unless C::StatementLine

      stmt_scope = Sources::Statement.capture_scope(scope, date, currency)
      if stmt_scope.exists?
        stmt_scope.sum(C::SL_AMOUNT).to_i
      else
        Sources::Accounting.total_for(scope, date, currency)
      end
    end
  end
end
