class CreateOtherResponses < ActiveRecord::Migration[8.1]
  # Materializes the free-text "Other" answers people type on tag-backed form
  # questions (sectors today; workshop settings could follow via `kind`). These
  # can't be Sector/Category records, so they were previously derived on the fly
  # from form answers. Capturing them as records lets a curator promote a
  # recurring value into a real tag, keep it as a free-text chip, or dismiss it.
  def up
    return if table_exists?(:other_responses)

    create_table :other_responses do |t|
      t.references :person, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :text, null: false
      t.string :normalized_text, null: false
      t.string :status, null: false, default: "pending"
      t.references :promotable, polymorphic: true, null: true
      t.references :source_form_answer, null: true, foreign_key: { to_table: :form_answers }
      t.timestamps
    end

    add_index :other_responses, [ :person_id, :kind, :normalized_text ],
              unique: true, name: "index_other_responses_on_person_kind_text"
  end

  def down
    drop_table :other_responses, if_exists: true
  end
end
