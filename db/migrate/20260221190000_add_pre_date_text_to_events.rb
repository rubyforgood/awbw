class AddPreDateTextToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :pre_date_text, :string
    add_column :events, :autoshow_pre_date_text, :boolean, default: true, null: false
  end
end
