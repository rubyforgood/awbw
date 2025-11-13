class AddAgencyTypeOtherToProject < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :agency_type_other, :string
  end
end
