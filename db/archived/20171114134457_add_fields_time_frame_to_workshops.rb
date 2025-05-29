class AddFieldsTimeFrameToWorkshops < ActiveRecord::Migration[4.2]
  def change
    add_column :workshops, :time_intro, :integer
    add_column :workshops, :time_demonstration, :integer
    add_column :workshops, :time_warm_up, :integer
    add_column :workshops, :time_creation, :integer
    add_column :workshops, :time_closing, :integer
  end
end
