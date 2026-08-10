class AddFormFilledFieldsToEventRegistrationOrganizations < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:event_registration_organizations, :form_filled_fields)

    add_column :event_registration_organizations, :form_filled_fields, :json
  end

  def down
    remove_column :event_registration_organizations, :form_filled_fields, if_exists: true
  end
end
