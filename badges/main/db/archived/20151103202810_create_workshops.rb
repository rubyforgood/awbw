class CreateWorkshops < ActiveRecord::Migration
  def change
    create_table :workshops do |t|
      t.string :title
      t.string :author_first_name
      t.string :author_last_name
      t.string :author_location
      t.integer :month
      t.integer :year
      t.text :objective
      t.text :materials
      t.text :timeframe
      t.text :age_range
      t.text :setup
      t.text :instructions
      t.text :warm_up
      t.text :creation
      t.text :closing
      t.text :misc_instructions
      t.text :project
      t.text :description
      t.text :notes
      t.text :timestamps
      t.text :tips
      t.string :pub_issue
      t.string :misc1
      t.string :misc2
      t.boolean :inactive, default: true
      t.boolean :searchable, default: false
      t.boolean :featured, default: false
      t.string :photo_caption
      t.string :filemaker_code
      t.timestamps null: false
      t.boolean :legacy, default: false
      t.integer :legacy_id
    end
  end
end
