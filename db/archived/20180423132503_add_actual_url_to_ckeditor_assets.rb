class AddActualUrlToCkeditorAssets < ActiveRecord::Migration
  def change
    add_column :ckeditor_assets, :actual_url, :string
  end
end
