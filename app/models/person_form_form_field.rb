class PersonFormFormField < ApplicationRecord
  belongs_to :form_field
  belongs_to :person_form

  def name
    "#{form_field.question}: #{text}"
  end
end
