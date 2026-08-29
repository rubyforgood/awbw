class AddAnonymousFormSubmissions < ActiveRecord::Migration[8.0]
  # Anonymity is a per-form property derived from whether the name/email
  # questions are required (see PublicFormSubmission) — no stored flag. All this
  # migration needs is to let a submission stand without a person.
  def up
    change_column_null :form_submissions, :person_id, true
  end

  def down
    # Can't restore NOT NULL while anonymous (person-less) submissions exist; the
    # feature that created them is being removed, so drop those rows first.
    execute "DELETE FROM form_submissions WHERE person_id IS NULL"
    change_column_null :form_submissions, :person_id, false
  end
end
