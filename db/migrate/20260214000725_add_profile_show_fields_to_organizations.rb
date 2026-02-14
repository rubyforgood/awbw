class AddProfileShowFieldsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :profile_show_sectors, :boolean, default: true, null: false
    add_column :organizations, :profile_show_email, :boolean, default: true, null: false
    add_column :organizations, :profile_show_phone, :boolean, default: true, null: false
    add_column :organizations, :profile_show_website, :boolean, default: true, null: false
    add_column :organizations, :profile_show_description, :boolean, default: true, null: false
    add_column :organizations, :profile_show_workshops, :boolean, default: true, null: false
    add_column :organizations, :profile_show_stories, :boolean, default: true, null: false
    add_column :organizations, :profile_show_events_registered, :boolean, default: true, null: false
    add_column :organizations, :profile_show_workshop_logs, :boolean, default: true, null: false
  end
end
