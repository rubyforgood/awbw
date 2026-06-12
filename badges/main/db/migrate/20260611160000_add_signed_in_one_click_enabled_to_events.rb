class AddSignedInOneClickEnabledToEvents < ActiveRecord::Migration[8.1]
  # Lets signed-in users register in one click even when a registration form
  # exists. The form is still required for logged-out visitors (we have none of
  # their details), but admins can let members skip it. Default false preserves
  # the existing behavior of routing signed-in users to a populated form.
  def up
    return if column_exists?(:events, :signed_in_one_click_enabled)
    add_column :events, :signed_in_one_click_enabled, :boolean, default: false, null: false
  end

  def down
    remove_column :events, :signed_in_one_click_enabled, if_exists: true
  end
end
