class ContactMethod < ApplicationRecord
  include Timelineable

  def self.timeline_renderer_class
    NestedRecordTimelineRenderer
  end

  CONTACT_METHOD_TIMELINE_ATTRIBUTES = %w[ value kind contact_type ].freeze

  CONTACT_TYPES = [ nil, "work", "personal" ].freeze

  belongs_to :contactable, polymorphic: true
  belongs_to :address, optional: true

  enum :kind, {
    phone: "phone",
    sms: "sms",
    whatsapp: "whatsapp"
  }

  validates :value, presence: true, length: { maximum: 255 }
  validates :kind, presence: true

  def timeline_label
    kind.humanize
  end

  def record_timeline_event(action)
    TimelineServices::RecordEvent.call(
      subject: self,
      action: action,
      snapshot: { "changes" => {} },
      also_log: timeline_also_log
    )
  end

  def timeline_changes
    saved_changes
      .slice(*CONTACT_METHOD_TIMELINE_ATTRIBUTES)
      .transform_values { |(old_value, new_value)| [ old_value.to_s, new_value.to_s ] }
  end
end
