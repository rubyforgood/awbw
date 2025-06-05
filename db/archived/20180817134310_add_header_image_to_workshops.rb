class AddHeaderImageToWorkshops < ActiveRecord::Migration
  def up
    add_attachment :workshops, :header
  end

  def down
    remove_attachment :workshops, :header
  end
end
