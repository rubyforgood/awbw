class CreateBanners < ActiveRecord::Migration
  def change
    create_table :banners do |t|
      t.text :content
      t.boolean :show

      t.timestamps null: false
    end
  end
end
