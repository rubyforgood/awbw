# frozen_string_literal: true

class Form < ApplicationRecord
  # Associations
  has_many :form_fields, dependent: :destroy, inverse_of: :form
  has_many :user_forms # rubocop:todo Rails/HasManyOrHasOneDependent
  has_many :reports, as: :owner # rubocop:todo Rails/HasManyOrHasOneDependent
  belongs_to :owner, polymorphic: true

  # Nested Attrs
  accepts_nested_attributes_for :form_fields, allow_destroy: true

  # Rails Admin
  rails_admin do
    exclude_fields :form_builder_id, :reports, :user_forms, form_fields: [:form]
  end

  def name
    owner ? "#{owner.try(:name)} Form" : "New Form"
  end
end
