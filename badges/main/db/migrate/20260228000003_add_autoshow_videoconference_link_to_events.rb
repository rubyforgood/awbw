class AddAutoshowVideoconferenceLinkToEvents < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:events, :autoshow_videoconference_link)
      add_column :events, :autoshow_videoconference_link, :boolean, default: true, null: false
    end
  end
end
