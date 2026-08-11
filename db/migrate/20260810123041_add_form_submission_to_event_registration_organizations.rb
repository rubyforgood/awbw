class AddFormSubmissionToEventRegistrationOrganizations < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:event_registration_organizations, :form_submission_id)
      add_reference :event_registration_organizations, :form_submission, type: :bigint, null: true, index: true
    end

    unless foreign_key_exists?(:event_registration_organizations, :form_submissions)
      add_foreign_key :event_registration_organizations, :form_submissions, on_delete: :nullify
    end
  end

  def down
    if foreign_key_exists?(:event_registration_organizations, :form_submissions)
      remove_foreign_key :event_registration_organizations, :form_submissions
    end

    remove_column :event_registration_organizations, :form_submission_id, if_exists: true
  end
end
