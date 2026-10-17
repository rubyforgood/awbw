class AllowInactiveRepeatEventRegistrations < ActiveRecord::Migration[8.1]
  INACTIVE_STATUSES_SQL = "'cancelled', 'no_show', 'transferred_out'".freeze
  OLD_INDEX = "index_event_registrations_on_registrant_id_and_event_id".freeze
  NEW_INDEX = "index_event_registrations_on_active_registrant_id_and_event_id".freeze

  # active_registrant_id is NULL on an inactive registration, and MySQL lets NULLs
  # repeat in a unique index — so a person keeps at most one active registration per
  # event while any number of cancelled / no-show / transferred-out ones sit beside it.
  def up
    unless column_exists?(:event_registrations, :active_registrant_id)
      add_column :event_registrations, :active_registrant_id, :virtual,
                 type: :bigint, stored: true,
                 as: "(CASE WHEN status IN (#{INACTIVE_STATUSES_SQL}) THEN NULL ELSE registrant_id END)"
    end
    add_index :event_registrations, %i[active_registrant_id event_id], unique: true, name: NEW_INDEX unless index_exists?(:event_registrations, %i[active_registrant_id event_id], name: NEW_INDEX)
    remove_index :event_registrations, name: OLD_INDEX, if_exists: true
  end

  def down
    add_index :event_registrations, %i[registrant_id event_id], unique: true, name: OLD_INDEX unless index_exists?(:event_registrations, %i[registrant_id event_id], name: OLD_INDEX)
    remove_index :event_registrations, name: NEW_INDEX, if_exists: true
    remove_column :event_registrations, :active_registrant_id if column_exists?(:event_registrations, :active_registrant_id)
  end
end
