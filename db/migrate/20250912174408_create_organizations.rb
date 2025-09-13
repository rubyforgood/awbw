class CreateOrganizations < ActiveRecord::Migration[6.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.boolean :is_active, default: true
      t.date :start_date
      t.date :close_date
      t.string :website_url
      t.string :agency_type, null: false
      t.string :agency_type_other
      t.string :phone, null: false
      t.text :mission
      t.string :project_id
      
      t.timestamps
    end
  end
end
