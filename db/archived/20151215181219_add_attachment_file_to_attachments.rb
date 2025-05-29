class AddAttachmentFileToAttachments < ActiveRecord::Migration[4.2]
  def self.up
    change_table :attachments do |t|
      t.attachment :file
    end
  end

  def self.down
    remove_attachment :attachments, :file
  end
end
