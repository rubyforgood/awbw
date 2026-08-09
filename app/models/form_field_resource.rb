class FormFieldResource < ApplicationRecord
  # Ordered join between a form field and the resources it fans out over. A field
  # with any of these is a "per-resource" question: on the survey page it renders
  # one input per linked resource (e.g. the post-event survey clarity question,
  # asked once per training topic/handout). The field owns the prompt wording and
  # answer options; each resource just supplies the item the prompt is asked about.
  belongs_to :form_field
  belongs_to :resource

  positioned on: :form_field_id

  validates :resource_id, uniqueness: { scope: :form_field_id }
  validates :position, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  scope :ordered, -> { order(:position, :id) }
end
