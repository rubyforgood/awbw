class AddReferenceUrlToWorkshopVariation < ActiveRecord::Migration[8.1]
  def change
    add_column :workshop_variations, :reference_url, :string
  end
end
