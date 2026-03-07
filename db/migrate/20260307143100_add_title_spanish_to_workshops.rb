class AddTitleSpanishToWorkshops < ActiveRecord::Migration[8.1]
  def change
    add_column :workshops, :title_spanish, :string
  end
end
