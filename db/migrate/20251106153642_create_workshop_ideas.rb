class CreateWorkshopIdeas < ActiveRecord::Migration[8.1]
  def change
    create_table :workshop_ideas do |t|
      t.string :title
      t.text :description
      t.text :staff_notes
      t.text :tips
      t.text :objective
      t.text :materials
      t.text :introduction
      t.text :creation
      t.text :closing
      t.text :visualization
      t.text :warm_up
      t.text :opening_circle
      t.text :demonstration
      t.text :setup
      t.text :instructions
      t.text :optional_materials
      t.text :notes
      t.text :age_range

      t.integer :time_closing
      t.integer :time_creation
      t.integer :time_demonstration
      t.integer :time_intro
      t.integer :time_opening
      t.integer :time_opening_circle
      t.integer :time_warm_up
      t.integer :time_hours
      t.integer :time_minutes
      t.text :timeframe

      t.text :age_range_spanish
      t.text :closing_spanish
      t.text :creation_spanish
      t.text :demonstration_spanish
      t.text :description_spanish
      t.text :instructions_spanish
      t.text :introduction_spanish
      t.text :materials_spanish
      t.text :misc_instructions_spanish
      t.text :notes_spanish
      t.text :objective_spanish
      t.text :opening_circle_spanish
      t.text :optional_materials_spanish
      t.text :setup_spanish
      t.text :timeframe_spanish
      t.text :tips_spanish
      t.text :visualization_spanish
      t.text :warm_up_spanish

      t.timestamps

      t.integer :windows_type_id, null: false, index: true
      t.integer :created_by_id, null: false, index: true
      t.integer :updated_by_id, null: false, index: true
    end

    # Add foreign keys separately
    add_foreign_key :workshop_ideas, :windows_types, column: :windows_type_id
    add_foreign_key :workshop_ideas, :users, column: :created_by_id
    add_foreign_key :workshop_ideas, :users, column: :updated_by_id
  end
end
