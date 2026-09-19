class ProfileChangeRequest < ApplicationRecord
  belongs_to :person
  belongs_to :requested_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  FIELDS = %w[primary_email organization_name affiliation].freeze
  FIELD_LABELS = {
    "primary_email" => "Primary email",
    "organization_name" => "Organization name",
    "affiliation" => "Affiliation details"
  }.freeze
  # Fields whose new value is concrete enough for "Approve" to write directly.
  AUTO_APPLIABLE_FIELDS = %w[primary_email organization_name].freeze
  STATUSES = %w[pending resolved declined].freeze
  RESOLUTION_METHODS = %w[approved manual].freeze

  validates :field, inclusion: { in: FIELDS }
  validates :status, inclusion: { in: STATUSES }
  validates :resolution_method, inclusion: { in: RESOLUTION_METHODS }, allow_nil: true
  validates :requested_value, presence: true, if: :auto_appliable?
  validates :requested_value, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" },
                              if: -> { field == "primary_email" && requested_value.present? }
  validates :details, presence: true, unless: :auto_appliable?

  scope :pending, -> { where(status: "pending") }
  scope :resolved, -> { where(status: "resolved") }
  scope :declined, -> { where(status: "declined") }
  scope :newest_first, -> { order(created_at: :desc) }

  def pending? = status == "pending"
  def resolved? = status == "resolved"
  def declined? = status == "declined"

  def auto_appliable?
    field.in?(AUTO_APPLIABLE_FIELDS)
  end

  def field_label
    FIELD_LABELS.fetch(field, field.humanize)
  end

  # The value the request would change, read live from the person.
  def current_value
    case field
    when "primary_email" then person.user&.email
    when "organization_name" then person.primary_organization&.name
    end
  end

  def resolve!(method:, reviewer:)
    update!(status: "resolved", resolution_method: method, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def decline!(reviewer:)
    update!(status: "declined", resolution_method: nil, reviewed_by: reviewer, reviewed_at: Time.current)
  end
end
