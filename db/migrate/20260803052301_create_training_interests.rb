class CreateTrainingInterests < ActiveRecord::Migration[8.1]
  def up
    create_table :training_interests do |t|
      t.references :person, null: false, foreign_key: true
      # Optional: a specific scheduled training the person is interested in.
      # Null means general interest in future trainings.
      t.references :event, null: true, foreign_key: true
      # When the interest was expressed. Distinct from created_at so a backfill
      # from historical registration answers can carry the original date.
      t.datetime :expressed_at, null: false
      # Where the interest came from (registration form, admin, import), mirroring
      # people.mailing_list_consent_source.
      t.string :source
      t.string :status, null: false, default: "open"
      t.text :note
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :training_interests, :status
    add_index :training_interests, :created_by_id
    add_index :training_interests, :updated_by_id
  end

  def down
    drop_table :training_interests, if_exists: true
  end
end
