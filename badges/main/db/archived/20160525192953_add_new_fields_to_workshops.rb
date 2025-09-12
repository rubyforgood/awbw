class AddNewFieldsToWorkshops < ActiveRecord::Migration
  def change
    add_column :workshops, :optional_materials, :text
    add_column :workshops, :optional_materials_spanish, :text
    add_column :workshops, :introduction, :text
    add_column :workshops, :introduction_spanish, :text
    add_column :workshops, :demonstration, :text
    add_column :workshops, :demonstration_spanish, :text
    add_column :workshops, :opening_circle, :text
    add_column :workshops, :opening_circle_spanish, :text
    add_column :workshops, :visualization, :text
    add_column :workshops, :visualization_spanish, :text
    add_column :workshops, :misc1_spanish, :text
    add_column :workshops, :misc2_spanish, :text
  end
end
