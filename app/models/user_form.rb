# frozen_string_literal: true

class UserForm < ApplicationRecord
  belongs_to :user
  belongs_to :form
  has_many :user_form_form_fields # rubocop:todo Rails/HasManyOrHasOneDependent

  accepts_nested_attributes_for :user_form_form_fields
end
