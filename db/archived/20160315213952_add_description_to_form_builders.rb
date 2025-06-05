class AddDescriptionToFormBuilders < ActiveRecord::Migration
  def change
    add_column :form_builders, :description, :text
  end
end
