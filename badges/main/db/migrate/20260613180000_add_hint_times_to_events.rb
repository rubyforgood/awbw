class AddHintTimesToEvents < ActiveRecord::Migration[8.1]
  # Optional admin-authored qualifier shown beside the Time(s) row of the
  # structured registration details panel (e.g. "both days"), mirroring the
  # existing hint_dates / hint_registration_cost qualifiers. Free-form and
  # nullable, so a blank value simply renders no note.
  def up
    unless column_exists?(:events, :hint_times)
      add_column :events, :hint_times, :string
    end
  end

  def down
    remove_column :events, :hint_times, if_exists: true
  end
end
