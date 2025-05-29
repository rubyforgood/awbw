class AddFileToReports < ActiveRecord::Migration[4.2]
  def up
    add_attachment :reports, :form_file
  end

  def down
    remove_attachment :reports, :form_file
  end
end
