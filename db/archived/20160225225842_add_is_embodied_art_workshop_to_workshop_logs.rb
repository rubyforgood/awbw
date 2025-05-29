class AddIsEmbodiedArtWorkshopToWorkshopLogs < ActiveRecord::Migration[4.2]
  def change
    add_column :workshop_logs, :is_embodied_art_workshop, :boolean, default: false
  end
end
