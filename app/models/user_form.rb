class UserForm < ApplicationRecord
  belongs_to :user
  belongs_to :form
  has_many :user_form_form_fields

  accepts_nested_attributes_for :user_form_form_fields
end
