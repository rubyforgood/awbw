class UserForm < ApplicationRecord
  belongs_to :user
  belongs_to :form
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :user_form_form_fields

  # Nested attributes
  accepts_nested_attributes_for :user_form_form_fields
end
