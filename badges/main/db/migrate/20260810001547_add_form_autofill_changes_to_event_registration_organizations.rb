class AddFormAutofillChangesToEventRegistrationOrganizations < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:event_registration_organizations, :form_autofill_changes)

    add_column :event_registration_organizations, :form_autofill_changes, :json
  end

  def down
    remove_column :event_registration_organizations, :form_autofill_changes, if_exists: true
  end
end
