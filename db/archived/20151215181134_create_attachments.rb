class CreateAttachments < ActiveRecord::Migration[4.2]
  def change
    create_table :attachments do |t|
      t.integer :owner_id
      t.string :owner_type

      t.timestamps null: false
    end
  end
end
