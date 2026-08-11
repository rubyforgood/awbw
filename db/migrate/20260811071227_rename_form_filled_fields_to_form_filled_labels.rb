class RenameFormFilledFieldsToFormFilledLabels < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:event_registration_organizations, :form_filled_fields)

    rename_column :event_registration_organizations, :form_filled_fields, :form_filled_labels
  end

  def down
    return unless column_exists?(:event_registration_organizations, :form_filled_labels)

    rename_column :event_registration_organizations, :form_filled_labels, :form_filled_fields
  end
end
