class CreateMediaFiles < ActiveRecord::Migration[4.2]
  def change
    create_table :media_files do |t|
      t.attachment :file
      t.integer :report_id
    end
  end
end
