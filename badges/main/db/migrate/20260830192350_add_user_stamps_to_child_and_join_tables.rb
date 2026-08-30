class AddUserStampsToChildAndJoinTables < ActiveRecord::Migration[8.1]
  # Child, join, asset, and reference tables that carry no stamp columns. Now that
  # editing an associated record no longer bumps its parent's updated_by, these need
  # their own stamps so an edit to one is attributable on its own. UserStampable fills
  # them going forward; data:backfill_user_stamps fills legacy rows from the Ahoy trail.
  TABLES = %i[
    action_text_mentions addresses answer_options assets attachments categorizable_items
    contact_methods event_forms event_registration_checklist_completions
    event_registration_organizations event_staffs form_answers form_builders form_fields
    form_field_answer_options locations media_files organization_obligations other_responses
    quotable_item_quotes registration_ticket_callout_resources report_form_field_answers
    sectorable_items user_forms user_form_form_fields workshop_resources workshop_series_memberships
  ].freeze

  def up
    TABLES.each do |table|
      add_column table, :created_by_id, :integer, null: true unless column_exists?(table, :created_by_id)
      add_column table, :updated_by_id, :integer, null: true unless column_exists?(table, :updated_by_id)
      add_index table, :created_by_id unless index_exists?(table, :created_by_id)
      add_index table, :updated_by_id unless index_exists?(table, :updated_by_id)
      add_foreign_key table, :users, column: :created_by_id unless foreign_key_exists?(table, :users, column: :created_by_id)
      add_foreign_key table, :users, column: :updated_by_id unless foreign_key_exists?(table, :users, column: :updated_by_id)
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users, column: :created_by_id if foreign_key_exists?(table, :users, column: :created_by_id)
      remove_foreign_key table, :users, column: :updated_by_id if foreign_key_exists?(table, :users, column: :updated_by_id)
      remove_index table, :created_by_id if index_exists?(table, :created_by_id)
      remove_index table, :updated_by_id if index_exists?(table, :updated_by_id)
      remove_column table, :created_by_id if column_exists?(table, :created_by_id)
      remove_column table, :updated_by_id if column_exists?(table, :updated_by_id)
    end
  end
end
