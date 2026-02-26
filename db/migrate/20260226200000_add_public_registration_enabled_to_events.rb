class AddPublicRegistrationEnabledToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :public_registration_enabled, :boolean, default: false, null: false
  end
end
