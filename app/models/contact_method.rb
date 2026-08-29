class ContactMethod < ApplicationRecord
  include Timelineable

  def self.timeline_renderer_class
    NestedRecordTimelineRenderer
  end

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
end
