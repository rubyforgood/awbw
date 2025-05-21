class AddPublishedToMetadatum < ActiveRecord::Migration
  def change
    add_column :metadata, :published, :boolean, default: false
  end
end
