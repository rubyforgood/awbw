class AddAttachmentThumbnailToWorkshops < ActiveRecord::Migration
  def self.up
    change_table :workshops do |t|
      t.attachment :thumbnail
    end
  end

  def self.down
    remove_attachment :workshops, :thumbnail
  end
end
