class RemoveEmailTypeDefaults < ActiveRecord::Migration[8.1]
  def up
    change_column_default :people, :email_2_type, from: "personal", to: nil
    change_column_null :people, :email_2_type, true

    change_column_default :users, :email_type, from: "work", to: nil
    change_column_null :users, :email_type, true
  end

  def down
    User.where(email_type: nil).update_all(email_type: "work")
    change_column_null :users, :email_type, false
    change_column_default :users, :email_type, from: nil, to: "work"

    Person.where(email_2_type: nil).update_all(email_2_type: "personal")
    change_column_null :people, :email_2_type, false
    change_column_default :people, :email_2_type, from: nil, to: "personal"
  end
end
