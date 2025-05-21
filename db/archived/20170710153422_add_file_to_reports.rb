class AddFileToReports < ActiveRecord::Migration
  def up
    add_attachment :reports, :form_file
  end

  def down
    remove_attachment :reports, :form_file
  end
end
