class AddPolymorphicFieldsToNotification < ActiveRecord::Migration
  def change
    add_column :notifications, :notification_type, :integer
    add_column :notifications, :noticeable_type, :string
    add_column :notifications, :noticeable_id, :integer
  end
end
