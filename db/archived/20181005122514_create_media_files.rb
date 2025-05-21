class CreateMediaFiles < ActiveRecord::Migration
  def change
    create_table :media_files do |t|
      t.attachment :file
      t.integer :report_id
    end
  end
end
