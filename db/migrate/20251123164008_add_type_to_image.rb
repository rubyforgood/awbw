class AddTypeToImage < ActiveRecord::Migration[8.1]
  def change
<<<<<<< HEAD
    add_column :images, :type, :string, null: false, default: "Images::GalleryImage"
=======
    add_column :images, :type, :string, null: false, default: "GalleryImage"
>>>>>>> b3025845 (Change Image to STI so MainImage can be separate from the rest of the images, now named GalleryImage)
    add_index  :images, :type
  end
end
