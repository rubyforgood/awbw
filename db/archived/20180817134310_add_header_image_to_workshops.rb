class AddHeaderImageToWorkshops < ActiveRecord::Migration[4.2]
  def up
    add_attachment :workshops, :header
  end

  def down
    remove_attachment :workshops, :header
  end
end
