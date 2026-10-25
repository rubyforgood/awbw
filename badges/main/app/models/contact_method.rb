class ContactMethod < ApplicationRecord
  include FilemakerCoded
  filemaker_archived_in FmPhoneNumber

  UNKNOWN_CONTACT_TYPE = "unknown"
  CONTACT_TYPES = [ nil, "work", "personal", UNKNOWN_CONTACT_TYPE ].freeze

  belongs_to :contactable, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  belongs_to :address, optional: true

  enum :kind, {
    phone: "phone",
    sms: "sms",
    whatsapp: "whatsapp"
  }

  before_validation :type_as_unknown

  validates :value, presence: true, length: { maximum: 255 }
  validates :kind, presence: true

  private

  # Every contact method carries a type, so one saved without an answer says so. Rows
  # written before this keep their blank until something saves them.
  def type_as_unknown
    self.contact_type = UNKNOWN_CONTACT_TYPE if contact_type.blank?
  end
end
