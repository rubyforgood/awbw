class PersonForm < ApplicationRecord
  belongs_to :person
  belongs_to :form
  has_many :person_form_form_fields, dependent: :destroy

  accepts_nested_attributes_for :person_form_form_fields
end
