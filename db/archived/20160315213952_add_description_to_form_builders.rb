class AddDescriptionToFormBuilders < ActiveRecord::Migration[4.2]
  def change
    add_column :form_builders, :description, :text
  end
end
