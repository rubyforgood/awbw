class RenameWorkshopVariationCodeToBody < ActiveRecord::Migration[8.1]
  def change
    rename_column :workshop_variations, :code, :body
  end
end
