class AddNotNullToMembershipsDates < ActiveRecord::Migration[8.1]
  def up
    # Memberships from the Stripe-subscription era have no term dates. Take the
    # term from their invoice coverage, else a one-year term from created_at.
    execute <<~SQL
      UPDATE memberships m
      LEFT JOIN (
        SELECT membership_id, MIN(start_date) AS first_start, MAX(end_date) AS last_end
        FROM membership_invoices
        GROUP BY membership_id
      ) coverage ON coverage.membership_id = m.id
      SET m.start_date = COALESCE(m.start_date, coverage.first_start, DATE(m.created_at)),
          m.end_date = COALESCE(
            m.end_date,
            coverage.last_end,
            DATE_SUB(DATE_ADD(COALESCE(m.start_date, coverage.first_start, DATE(m.created_at)), INTERVAL 1 YEAR), INTERVAL 1 DAY)
          )
      WHERE m.start_date IS NULL OR m.end_date IS NULL
    SQL

    change_column_null :memberships, :start_date, false
    change_column_null :memberships, :end_date, false
  end

  def down
    change_column_null :memberships, :start_date, true
    change_column_null :memberships, :end_date, true
  end
end
