class AddScholarshipApplicationToForms < ActiveRecord::Migration[8.1]
  def change
    add_column :forms, :scholarship_application, :boolean, default: false, null: false
  end
end
