class MaterializeTicketCallouts < ActiveRecord::Migration[8.1]
  # Turns the code-defined "magic" ticket callouts into editable rows and lets a
  # callout link many resources instead of one:
  #   * magic_key    — hidden identifier tying a seeded row back to its built-in
  #                    behavior (badges, per-registration visibility). nil for
  #                    admin-authored custom callouts.
  #   * hidden       — draft/opt-out flag. Custom callouts prep hidden; magic
  #                    callouts are hidden rather than destroyed so they can be
  #                    restored to their default later.
  #   * display_from — drip date; the callout only appears on/after it (e.g. the
  #                    videoconference card, seeded to a week before the event).
  # The single resource_id belongs_to is replaced by an ordered join table.
  def up
    add_column :registration_ticket_callouts, :magic_key, :string
    add_index :registration_ticket_callouts, [ :event_id, :magic_key ]
    add_column :registration_ticket_callouts, :hidden, :boolean, null: false, default: false
    add_column :registration_ticket_callouts, :display_from, :datetime

    create_table :registration_ticket_callout_resources do |t|
      t.references :registration_ticket_callout, null: false, foreign_key: { on_delete: :cascade },
                   index: { name: "index_callout_resources_on_callout_id" }
      # resources.id is a legacy `int` (not bigint), so the FK column must match.
      t.integer :resource_id, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_foreign_key :registration_ticket_callout_resources, :resources, on_delete: :cascade
    add_index :registration_ticket_callout_resources, [ :registration_ticket_callout_id, :resource_id ],
              unique: true, name: "index_callout_resources_on_callout_and_resource"
    add_index :registration_ticket_callout_resources, :resource_id, name: "index_callout_resources_on_resource_id"

    # Carry each existing single link over to the join table as the first item.
    execute <<~SQL.squish
      INSERT INTO registration_ticket_callout_resources
        (registration_ticket_callout_id, resource_id, position, created_at, updated_at)
      SELECT id, resource_id, 1, NOW(), NOW()
      FROM registration_ticket_callouts
      WHERE resource_id IS NOT NULL
    SQL

    if foreign_key_exists?(:registration_ticket_callouts, :resources)
      remove_foreign_key :registration_ticket_callouts, :resources
    end
    remove_column :registration_ticket_callouts, :resource_id
  end

  def down
    add_reference :registration_ticket_callouts, :resource, type: :integer, null: true, index: true
    add_foreign_key :registration_ticket_callouts, :resources, on_delete: :nullify

    # Restore the lowest-positioned resource as the single link.
    execute <<~SQL.squish
      UPDATE registration_ticket_callouts c
      JOIN (
        SELECT registration_ticket_callout_id, MIN(position) AS min_position
        FROM registration_ticket_callout_resources
        GROUP BY registration_ticket_callout_id
      ) firsts ON firsts.registration_ticket_callout_id = c.id
      JOIN registration_ticket_callout_resources r
        ON r.registration_ticket_callout_id = c.id AND r.position = firsts.min_position
      SET c.resource_id = r.resource_id
    SQL

    drop_table :registration_ticket_callout_resources, if_exists: true

    remove_column :registration_ticket_callouts, :display_from, if_exists: true
    remove_column :registration_ticket_callouts, :hidden, if_exists: true
    if index_exists?(:registration_ticket_callouts, [ :event_id, :magic_key ])
      remove_index :registration_ticket_callouts, [ :event_id, :magic_key ]
    end
    remove_column :registration_ticket_callouts, :magic_key, if_exists: true
  end
end
