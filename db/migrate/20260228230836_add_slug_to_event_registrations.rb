class AddSlugToEventRegistrations < ActiveRecord::Migration[8.0]
  def change
    add_column :event_registrations, :slug, :string unless column_exists?(:event_registrations, :slug)
    add_index :event_registrations, :slug, unique: true unless index_exists?(:event_registrations, :slug)
  end
end
