class UpdateFacilitator < ActiveRecord::Migration[8.1]
  def change
    add_column :facilitators, :bio, :text
    add_column :facilitators, :pronouns, :string
    add_column :facilitators, :member_since, :date

    add_column :facilitators, :display_name_preference, :string
    add_column :facilitators, :profile_is_searchable, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_member_since, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_pronouns, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_phone, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_email, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_bio, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_sectors, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_organizations, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_social_media, :boolean, null: false, default: true

    add_column :facilitators, :profile_show_events_registered, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_stories, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_story_ideas, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_workshop_variations, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_workshop_ideas, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_workshops, :boolean, null: false, default: true
    add_column :facilitators, :profile_show_workshop_logs, :boolean, null: false, default: true

    add_column :facilitators, :linked_in_url, :string
    add_column :facilitators, :facebook_url, :string
    add_column :facilitators, :instagram_url, :string
    add_column :facilitators, :youtube_url, :string
    add_column :facilitators, :twitter_url, :string

    add_column :facilitators, :created_by_id, :integer, null: true
    add_column :facilitators, :updated_by_id, :integer, null: true
    add_index :facilitators, :created_by_id
    add_index :facilitators, :updated_by_id
    add_foreign_key :facilitators, :users, column: :created_by_id
    add_foreign_key :facilitators, :users, column: :updated_by_id

    change_column_null :facilitators, :city, true
    change_column_null :facilitators, :country, true
    change_column_null :facilitators, :mailing_address_type, true
    change_column_null :facilitators, :phone_number, true
    change_column_null :facilitators, :phone_number_type, true
    change_column_null :facilitators, :primary_email_address, true
    change_column_null :facilitators, :primary_email_address_type, true
    change_column_null :facilitators, :state, true
    change_column_null :facilitators, :street_address, true
    change_column_null :facilitators, :zip, true
  end
end
