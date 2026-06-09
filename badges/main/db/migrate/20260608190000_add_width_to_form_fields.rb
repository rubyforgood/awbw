class AddWidthToFormFields < ActiveRecord::Migration[8.1]
  # Layout widths previously hardcoded by field_identifier in the form views.
  # Backfill them so existing forms keep their multi-column appearance now that
  # width is configurable per field.
  HALF = %w[
    first_name last_name nickname pronouns primary_email confirm_email
    mailing_street mailing_address_type phone phone_type agency_name
    agency_position secondary_email secondary_email_type
  ].freeze
  THIRD = %w[mailing_city mailing_state mailing_zip agency_city agency_state agency_zip].freeze

  def up
    add_column :form_fields, :width, :integer, default: 0, null: false unless column_exists?(:form_fields, :width)

    FormField.reset_column_information
    FormField.where(field_identifier: HALF).update_all(width: 1)
    FormField.where(field_identifier: THIRD).update_all(width: 2)
  end

  def down
    remove_column :form_fields, :width, if_exists: true
  end
end
