class AddVideoconferencePasscodeToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :videoconference_passcode, :string unless column_exists?(:events, :videoconference_passcode)
  end

  def down
    remove_column :events, :videoconference_passcode if column_exists?(:events, :videoconference_passcode)
  end
end
