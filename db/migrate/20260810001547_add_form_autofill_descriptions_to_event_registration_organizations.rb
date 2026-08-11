class AddFormAutofillDescriptionsToEventRegistrationOrganizations < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:event_registration_organizations, :form_autofill_descriptions)

    add_column :event_registration_organizations, :form_autofill_descriptions, :json
  end

  def down
    remove_column :event_registration_organizations, :form_autofill_descriptions, if_exists: true
  end
end
