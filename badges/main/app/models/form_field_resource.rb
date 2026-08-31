class FormFieldResource < ApplicationRecord
  # Ordered FormField→Resource join. A field with any of these is a "per-resource"
  # question: the survey page renders one input per linked resource (the clarity
  # question, asked once per training topic). The field owns the prompt + options.
  belongs_to :form_field
  belongs_to :resource

  positioned on: :form_field_id

  validates :resource_id, uniqueness: { scope: :form_field_id }
  validates :position, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  scope :ordered, -> { order(:position, :id) }
end
