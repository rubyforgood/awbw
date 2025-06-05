class AddSpanishFieldsToWorkshops < ActiveRecord::Migration
  def change
    add_column :workshops, :objective_spanish, :text
    add_column :workshops, :materials_spanish, :text
    add_column :workshops, :timeframe_spanish, :text
    add_column :workshops, :age_range_spanish, :text
    add_column :workshops, :setup_spanish, :text
    add_column :workshops, :instructions_spanish, :text
    add_column :workshops, :project_spanish, :text
    add_column :workshops, :warm_up_spanish, :text
    add_column :workshops, :creation_spanish, :text
    add_column :workshops, :closing_spanish, :text
    add_column :workshops, :misc_instructions_spanish, :text
    add_column :workshops, :description_spanish, :text
    add_column :workshops, :notes_spanish, :text
    add_column :workshops, :tips_spanish, :text
  end
end
