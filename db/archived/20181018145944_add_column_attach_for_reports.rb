class AddColumnAttachForReports < ActiveRecord::Migration[4.2]
  def change
    add_column :reports, :has_attachment, :boolean, default: false
  end
end
