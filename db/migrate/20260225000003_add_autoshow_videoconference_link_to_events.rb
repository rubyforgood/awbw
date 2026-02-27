class AddAutoshowVideoconferenceLinkToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :autoshow_videoconference_link, :boolean, default: true, null: false
  end
end
