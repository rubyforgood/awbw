class RenameAutoshowVideoconferenceLinkAndAddLabel < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:events, :autoshow_videoconference_label)
      add_column :events, :autoshow_videoconference_label, :boolean, default: true, null: false
    end
    unless column_exists?(:events, :videoconference_label)
      add_column :events, :videoconference_label, :string, default: "Virtual event"
    end
    if column_exists?(:events, :autoshow_videoconference_url)
      remove_column :events, :autoshow_videoconference_url, :boolean, default: true, null: false
    end
  end
end
