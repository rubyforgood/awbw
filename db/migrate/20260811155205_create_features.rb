class CreateFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :features do |t|
      t.string :name, null: false
      t.string :area, null: false
      t.string :display_status, null: false, default: "user_facing"
      t.string :summary, null: false
      t.text :pro_tips
      t.string :external_url
      t.date :released_on, null: false
      t.boolean :published, null: false, default: true

      t.timestamps
    end

    add_index :features, :released_on
    add_index :features, :area
    add_index :features, :display_status
  end
end
