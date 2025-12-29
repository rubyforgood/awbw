class ContactMethod < ApplicationRecord
  CONTACT_TYPES = [ nil, "work", "personal" ].freeze

  belongs_to :contactable, polymorphic: true
  belongs_to :address, optional: true

  enum :kind, {
    phone: "phone",
    sms: "sms",
    whatsapp: "whatsapp"
  }

  validates :value, presence: true
  validates :kind, presence: true
end
