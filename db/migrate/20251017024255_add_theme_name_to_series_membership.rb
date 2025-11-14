class AddThemeNameToSeriesMembership < ActiveRecord::Migration[8.1]
  def change
    add_column :workshop_series_memberships, :theme_name, :string
  end
end
