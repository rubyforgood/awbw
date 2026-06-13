class AddDetailHintsToEvents < ActiveRecord::Migration[8.1]
  # Optional admin-authored qualifiers shown beside the Dates and Fee rows of the
  # structured registration details panel (e.g. "must attend both days", "due
  # within 3 weeks of registration"). Free-form so they can vary per event;
  # nullable, so a blank value simply renders no note.
  def up
    unless column_exists?(:events, :hint_dates)
      add_column :events, :hint_dates, :string
    end
    unless column_exists?(:events, :hint_registration_cost)
      add_column :events, :hint_registration_cost, :string
    end
  end

  def down
    remove_column :events, :hint_registration_cost, if_exists: true
    remove_column :events, :hint_dates, if_exists: true
  end
end
