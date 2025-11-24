class AddTypeToImage < ActiveRecord::Migration[8.1]
  def change
    add_column :images, :type, :string, null: false, default: "Images::GalleryImage"
    add_index  :images, :type
  end
end
