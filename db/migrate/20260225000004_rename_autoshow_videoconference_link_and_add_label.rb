class RenameAutoshowVideoconferenceLinkAndAddLabel < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :autoshow_videoconference_label, :boolean, default: true, null: false
    add_column :events, :videoconference_label, :string, default: "Virtual event"
    remove_column :events, :autoshow_videoconference_url, :boolean, default: true, null: false
  end
end
