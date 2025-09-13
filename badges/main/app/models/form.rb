class Form < ApplicationRecord
  # Associations
  has_many :form_fields, dependent: :destroy, inverse_of: :form
  has_many :user_forms
  has_many :reports, as: :owner
  belongs_to :owner, polymorphic: true

  # Nested Attrs
  accepts_nested_attributes_for :form_fields, allow_destroy: true

  def name
    owner ? "#{owner.try(:name)} Form" : 'New Form'
  end
end
