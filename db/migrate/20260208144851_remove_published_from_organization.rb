class RemovePublishedFromOrganization < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :published, :boolean, null: false, default: false
  end
end
