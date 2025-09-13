class RemoveEmailFromFacilitators < ActiveRecord::Migration[6.1]
  def change
    remove_column :facilitators, :email, :string
  end
end
