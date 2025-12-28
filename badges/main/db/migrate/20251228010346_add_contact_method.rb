class AddContactMethod < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_methods do |t|
      t.references :contactable, polymorphic: true, null: false
      t.references :address, foreign_key: true, null: true

      t.string :kind, null: false        # phone, sms, whatsapp
      t.string :value, null: false       # "+15551234567"
      t.string :contact_type             # work, personal, office
      t.boolean :is_primary, null: false, default: false
      t.boolean :inactive, null: false, default: false

      t.timestamps
    end
  end
end
