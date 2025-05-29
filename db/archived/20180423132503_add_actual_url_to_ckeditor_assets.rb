class AddActualUrlToCkeditorAssets < ActiveRecord::Migration[4.2]
  def change
    add_column :ckeditor_assets, :actual_url, :string
  end
end
