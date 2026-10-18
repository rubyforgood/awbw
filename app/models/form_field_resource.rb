class FormFieldResource < ApplicationRecord
  # Ordered FormField→topic join: each row points at a workshop or a resource. A
  # field with any of these is a "per-resource" question: every form page renders
  # one input per link (the clarity question, asked once per training topic). The
  # field owns the prompt + options.
  belongs_to :form_field
  belongs_to :resource, optional: true
  belongs_to :workshop, optional: true

  positioned on: :form_field_id

  validates :resource_id, uniqueness: { scope: :form_field_id }, allow_nil: true
  validates :workshop_id, uniqueness: { scope: :form_field_id }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validate :links_one_topic

  scope :ordered, -> { order(:position, :id) }

  def topic
    workshop || resource
  end

  # The editor picks either kind from one search (SearchController "workshop_or_resource").
  def topic_sgid
    topic&.to_signed_global_id&.to_s
  end

  def topic_sgid=(sgid)
    return if sgid.blank?

    record = GlobalID::Locator.locate_signed(sgid, only: [ Workshop, Resource ])
    self.workshop = record.is_a?(Workshop) ? record : nil
    self.resource = record.is_a?(Resource) ? record : nil
  end

  private

  def links_one_topic
    return if [ resource, workshop ].compact.one?

    errors.add(:base, "Pick one workshop or resource")
  end
end
