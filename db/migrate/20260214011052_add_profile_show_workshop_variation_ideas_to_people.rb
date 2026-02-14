class AddProfileShowWorkshopVariationIdeasToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :profile_show_workshop_variation_ideas, :boolean, default: true, null: false
  end
end
