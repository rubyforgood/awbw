class AddAutoshowAndBottomDescriptionToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :autoshow_date, :boolean, default: true, null: false
    add_column :events, :autoshow_time, :boolean, default: true, null: false
    add_column :events, :autoshow_registration, :boolean, default: true, null: false
    add_column :events, :autoshow_location, :boolean, default: true, null: false
    add_column :events, :autoshow_videoconference_url, :boolean, default: true, null: false
    add_column :events, :autoshow_cost, :boolean, default: true, null: false
    add_column :events, :autoshow_title, :boolean, default: true, null: false
  end
end
