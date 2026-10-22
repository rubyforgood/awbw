class ContactMethod < ApplicationRecord
  CONTACT_TYPES = [ nil, "work", "personal" ].freeze

  belongs_to :contactable, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  belongs_to :address, optional: true

  enum :kind, {
    phone: "phone",
    sms: "sms",
    whatsapp: "whatsapp"
  }

  validates :value, presence: true, length: { maximum: 255 }
  validates :kind, presence: true
end
