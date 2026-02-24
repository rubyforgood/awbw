class AddAuthorCreditPreference < ActiveRecord::Migration[8.1]
  def change
    rename_column :story_ideas, :publish_preferences, :author_credit_preference
    rename_column :workshop_variation_ideas, :publish_preferences, :author_credit_preference
    add_column :stories, :author_credit_preference, :string
    add_column :workshops, :author_credit_preference, :string
    add_column :workshop_ideas, :author_credit_preference, :string
    add_column :workshop_variations, :author_credit_preference, :string
  end
end
