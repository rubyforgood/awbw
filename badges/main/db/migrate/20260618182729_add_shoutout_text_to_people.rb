class AddShoutoutTextToPeople < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:people, :shoutout_text)
    add_column :people, :shoutout_text, :text
  end

  def down
    remove_column :people, :shoutout_text, if_exists: true
  end
end
