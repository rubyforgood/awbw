class RemoveEmailTypeDefaults < ActiveRecord::Migration[8.1]
  def change
    change_column_default :people, :email_2_type, from: "personal", to: nil
    change_column_null :people, :email_2_type, true

    change_column_default :users, :email_type, from: "work", to: nil
    change_column_null :users, :email_type, true
  end
end
