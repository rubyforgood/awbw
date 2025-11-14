class ChangeFacilitatorsIdToInteger < ActiveRecord::Migration[8.1]
  def up
    # Drop dependent foreign keys first
    remove_foreign_key :stories, :facilitators, column: :spotlighted_facilitator_id rescue nil
    remove_foreign_key :facilitator_organizations, :facilitators rescue nil
    remove_foreign_key :users, :facilitators rescue nil

    # Change column types
    change_column :facilitators, :id, :integer
    change_column :facilitator_organizations, :facilitator_id, :integer
    change_column :users, :facilitator_id, :integer
    change_column :stories, :spotlighted_facilitator_id, :integer

    # Re-add foreign keys
    add_foreign_key :stories, :facilitators, column: :spotlighted_facilitator_id
    add_foreign_key :facilitator_organizations, :facilitators
    add_foreign_key :users, :facilitators
  end

  def down
    # Drop foreign keys first
    remove_foreign_key :facilitator_organizations, :facilitators rescue nil
    remove_foreign_key :users, :facilitators rescue nil
    remove_foreign_key :stories, :facilitators, column: :spotlighted_facilitator_id rescue nil

    # Change column types back to bigints (Rails default for id)
    change_column :facilitators, :id, :bigint
    change_column :facilitator_organizations, :facilitator_id, :bigint
    change_column :users, :facilitator_id, :bigint
    change_column :stories, :spotlighted_facilitator_id, :bigint

    # Re-add the original foreign keys
    add_foreign_key :facilitator_organizations, :facilitators
    add_foreign_key :users, :facilitators
    add_foreign_key :stories, :facilitators, column: :spotlighted_facilitator_id
  end
end
