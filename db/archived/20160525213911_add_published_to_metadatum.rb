class AddPublishedToMetadatum < ActiveRecord::Migration[4.2]
  def change
    add_column :metadata, :published, :boolean, default: false
  end
end
