class NormalizeBlankScopes < ActiveRecord::Migration[8.0]
  def up
    update_columns_to_null :report_files, :account_code
    update_columns_to_null :daily_summaries, :account_code
    update_columns_to_null :reconciliation_days, :account_scope
    update_columns_to_null :payout_matches, :account_scope
    update_columns_to_null :fee_breakdowns, :account_scope
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot restore blank scopes once normalized"
  end

  private

  def update_columns_to_null(table, column)
    quoted_column = connection.quote_column_name(column)
    execute <<~SQL.squish
      UPDATE #{table}
         SET #{quoted_column} = NULL
       WHERE #{quoted_column} IS NOT NULL
         AND TRIM(#{quoted_column}) = ''
    SQL
  end
end
