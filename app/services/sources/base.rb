# frozen_string_literal: true
module Sources
  class Base
    # scope: nil or composite String built via Sources::ScopeKey
    # date:  Date
    # currency: "USD" etc.
    # kind: :statement or :accounting
    def self.latest_rf_per_ba(model_klass:, kind:, scope:, date:, currency:, category_filter: nil, type_filter: nil)
      rf_kind = ReportFile.kinds.fetch(kind.to_s)

      table = model_klass.arel_table
      join_sql = "JOIN report_files rf ON rf.id = #{table.name}.report_file_id"

      rel = model_klass.joins(join_sql)
                       .where("rf.kind = ?", rf_kind)
                       .where(
                         "COALESCE(#{table.name}.book_date, #{table.name}.occurred_on, rf.reported_on) = ?",
                         date
                       )
                       .where("COALESCE(#{table.name}.currency, rf.currency) = ?", currency)

      account_code, account_holder = Sources::ScopeKey.parse(scope)

      rel = if account_code.nil? && account_holder.nil?
              rel.where("COALESCE(rf.account_code, '') = ''")
                 .where("COALESCE(rf.account_id, '') = ''")
            else
              scoped = rel
              scoped = scoped.where("rf.account_code = ?", account_code) if account_code
              scoped = scoped.where("rf.account_id = ?", account_holder) if account_holder
              scoped
            end

      if category_filter
        rel = rel.where("LOWER(#{table.name}.category) IN (?)", Array(category_filter).map(&:downcase))
      end
      if type_filter
        rel = rel.where("LOWER(#{table.name}.type) IN (?)", Array(type_filter).map(&:downcase))
      end

      # One latest report_file per BA
      rel.group("#{table.name}.balance_account_id").maximum("rf.id") # => { "BAxxx" => latest_rf_id }
    end

    def self.sum_for_pairs(model_klass, pairs, date:, currency:, category_filter: nil, type_filter: nil)
      return 0 if pairs.empty?

      table = model_klass.arel_table
      pairs.sum do |ba, rfid|
        scope = model_klass.where(report_file_id: rfid, balance_account_id: ba)
                           .where(
                             "(#{table.name}.book_date = :d) OR (#{table.name}.book_date IS NULL AND #{table.name}.occurred_on = :d)",
                             d: date
                           )
                           .where("#{table.name}.currency = ?", currency)
        if category_filter
          scope = scope.where("LOWER(#{table.name}.category) IN (?)", Array(category_filter).map(&:downcase))
        end
        if type_filter
          scope = scope.where("LOWER(#{table.name}.type) IN (?)", Array(type_filter).map(&:downcase))
        end
        scope.sum(:amount_minor).to_i
      end
    end
  end
end
