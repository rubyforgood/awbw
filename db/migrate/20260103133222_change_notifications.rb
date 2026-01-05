class ChangeNotifications < ActiveRecord::Migration[8.1]
  def change
    change_table :notifications do |t|
      t.string  :kind, null: false
      t.string  :recipient_role, null: false
      t.string  :recipient_email, null: false

      t.text :email_subject
      t.text :email_body_html
      t.text :email_body_text
      t.datetime :delivered_at
    end

    add_index :notifications, [ :noticeable_type, :noticeable_id ]
    add_index :notifications, :kind
  end
end
