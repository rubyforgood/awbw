# coding: utf-8
class AddExtraFieldToWorkshops < ActiveRecord::Migration[4.2]
  def change
    add_column :workshops, :extra_field, :string
    add_column :workshops, :extra_field_spanish, :string
  end
end
