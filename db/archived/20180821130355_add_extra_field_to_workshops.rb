# coding: utf-8
class AddExtraFieldToWorkshops < ActiveRecord::Migration
  def change
    add_column :workshops, :extra_field, :string
    add_column :workshops, :extra_field_spanish, :string
  end
end
