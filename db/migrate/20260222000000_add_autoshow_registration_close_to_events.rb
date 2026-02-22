class AddAutoshowRegistrationCloseToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :autoshow_registration_close, :boolean, default: true, null: false
  end
end
