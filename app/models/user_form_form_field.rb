class UserFormFormField < ApplicationRecord
  belongs_to :form_field
  belongs_to :user_form
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  def name
    "#{form_field.name}: #{text}"
  end
end
