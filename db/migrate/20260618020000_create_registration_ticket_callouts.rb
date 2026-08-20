class CreateRegistrationTicketCallouts < ActiveRecord::Migration[8.1]
  def up
    create_table :registration_ticket_callouts do |t|
      t.references :event, null: false, foreign_key: true
      t.string :title, null: false
      t.string :subtitle
      t.text :description
      t.string :callout_type, null: false, default: "reference"
      t.string :icon_class
      t.string :color_class
      t.boolean :show_if_paid, null: false, default: false
      # No default: the positioning gem assigns position before insert. A default
      # would let a freshly built record fail the `greater_than: 0` validation.
      t.integer :position, null: false
      t.timestamps
    end

    add_index :registration_ticket_callouts, [ :event_id, :position ]
  end

  def down
    drop_table :registration_ticket_callouts, if_exists: true
  end
end
