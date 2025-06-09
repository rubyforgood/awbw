class ChangeExtraFieldDataType < ActiveRecord::Migration
  def self.up
    change_column :workshops, :extra_field, :text
    change_column :workshops, :extra_field_spanish, :text
  end

  def self.down
    change_column :workshops, :extra_field, :string
    change_column :workshops, :extra_field_spanish, :string
  end

end
