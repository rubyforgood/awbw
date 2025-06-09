class AddColumnAttachForReports < ActiveRecord::Migration
  def change
    add_column :reports, :has_attachment, :boolean, default: false
  end
end
