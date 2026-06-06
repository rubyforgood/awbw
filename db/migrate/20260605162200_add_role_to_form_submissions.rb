class AddRoleToFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :form_submissions, :role, :string
  end
end
