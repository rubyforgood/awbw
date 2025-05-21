class UserFormFormField < ApplicationRecord
  belongs_to :form_field
  belongs_to :user_form

  def name
    "#{form_field.question}: #{text}"
  end
end
