class ProfileChangeRequest < ApplicationRecord
  belongs_to :person
  belongs_to :requested_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true
  # The specific records a request targets, snapshotted at submission so a later
  # change to the person's affiliations can't move the target out from under it.
  belongs_to :organization, optional: true
  belongs_to :affiliation, optional: true

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
  # What an affiliation request is asking to change (stored in requested_value),
  # so the person picks a structured category rather than only free text.
  AFFILIATION_CHANGE_TITLE = "Title or role".freeze
  AFFILIATION_CHANGE_DATES = "Start or end dates".freeze
  AFFILIATION_CHANGE_ORGANIZATION = "Organization".freeze
  AFFILIATION_CHANGE_REMOVE = "Remove this affiliation".freeze
  AFFILIATION_CHANGE_ADD = "Add a new affiliation".freeze
  AFFILIATION_CHANGE_OTHER = "Other".freeze
  AFFILIATION_CHANGE_TYPES = [
    AFFILIATION_CHANGE_TITLE,
    AFFILIATION_CHANGE_DATES,
    AFFILIATION_CHANGE_ORGANIZATION,
    AFFILIATION_CHANGE_REMOVE,
    AFFILIATION_CHANGE_ADD,
    AFFILIATION_CHANGE_OTHER
  ].freeze
  # Every affiliation category except "Other" carries a structured value Approve
  # can apply directly; "Other" is free text an admin handles by hand.
  AFFILIATION_AUTO_CATEGORIES = (AFFILIATION_CHANGE_TYPES - [ AFFILIATION_CHANGE_OTHER ]).freeze

  validates :field, inclusion: { in: FIELDS }
  validates :status, inclusion: { in: STATUSES }
  validates :resolution_method, inclusion: { in: RESOLUTION_METHODS }, allow_nil: true
  validates :requested_value, presence: true
  validates :requested_value, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" },
                              if: -> { field == "primary_email" && requested_value.present? }
  validates :details, presence: true, if: :requires_details?
  validate :affiliation_belongs_to_person
  validate :affiliation_target_present, if: -> { field == "affiliation" }
  validate :affiliation_proposed_values, if: -> { field == "affiliation" }
  validate :one_pending_per_target, if: :pending?

  before_validation :snapshot_target, on: :create
  before_validation :clear_irrelevant_affiliation_fields, if: -> { field == "affiliation" }

  scope :pending, -> { where(status: "pending") }
  scope :resolved, -> { where(status: "resolved") }
  scope :declined, -> { where(status: "declined") }
  scope :newest_first, -> { order(created_at: :desc) }

  def pending? = status == "pending"
  def resolved? = status == "resolved"
  def declined? = status == "declined"

  def auto_appliable?
    return true if field.in?(AUTO_APPLIABLE_FIELDS)
    field == "affiliation" && requested_value.in?(AFFILIATION_AUTO_CATEGORIES)
  end

  def field_label
    FIELD_LABELS.fetch(field, field.humanize)
  end

  # A human-readable summary of the proposed change, for the admin card and emails.
  def proposed_change_summary
    return unless field == "affiliation"

    case requested_value
    when AFFILIATION_CHANGE_TITLE then proposed_title
    when AFFILIATION_CHANGE_DATES then proposed_dates_label
    when AFFILIATION_CHANGE_ORGANIZATION then proposed_organization_name
    when AFFILIATION_CHANGE_REMOVE then "End-date and mark inactive"
    when AFFILIATION_CHANGE_ADD then [ proposed_title, organization&.name, proposed_dates_label ].compact_blank.join(" · ")
    end
  end

  def proposed_dates_label
    start_text = proposed_start_date&.strftime("%b %-d, %Y")
    end_text = proposed_end_date&.strftime("%b %-d, %Y")
    return "#{start_text} – #{end_text}" if start_text && end_text
    return "Starts #{start_text}" if start_text
    "Ends #{end_text}" if end_text
  end

  # The organization an "organization name" request renames. Snapshotted on
  # create; falls back to the person's primary organization for older rows.
  def target_organization
    organization || person.primary_organization
  end

  # The value the request would change, read live from the person.
  def current_value
    case field
    when "primary_email" then person.user&.email
    when "organization_name" then target_organization&.name
    end
  end

  # A one-line description of the affiliation an affiliation request targets.
  def affiliation_summary
    return unless affiliation

    org = affiliation.organization&.name
    [ affiliation.title.presence || Affiliation::FACILITATOR_TITLE, org ].compact.join(" @ ")
  end

  def resolve!(method:, reviewer:, note: nil)
    update!(status: "resolved", resolution_method: method, reviewed_by: reviewer,
            reviewed_at: Time.current, reviewer_note: note.presence)
  end

  def decline!(reviewer:, note: nil)
    update!(status: "declined", resolution_method: nil, reviewed_by: reviewer,
            reviewed_at: Time.current, reviewer_note: note.presence)
  end

  private

  def snapshot_target
    self.organization ||= person&.primary_organization if field == "organization_name"
  end

  def requires_details?
    field == "affiliation" && requested_value == AFFILIATION_CHANGE_OTHER
  end

  # A category's hidden sibling inputs still post their (stale) values; drop the
  # ones this category doesn't use so the stored request stays clean.
  def clear_irrelevant_affiliation_fields
    self.affiliation_id = nil if requested_value == AFFILIATION_CHANGE_ADD
    self.organization_id = nil unless requested_value == AFFILIATION_CHANGE_ADD
    self.proposed_title = nil unless requested_value.in?([ AFFILIATION_CHANGE_TITLE, AFFILIATION_CHANGE_ADD ])
    unless requested_value.in?([ AFFILIATION_CHANGE_DATES, AFFILIATION_CHANGE_ADD ])
      self.proposed_start_date = nil
      self.proposed_end_date = nil
    end
    self.proposed_organization_name = nil unless requested_value == AFFILIATION_CHANGE_ORGANIZATION
  end

  def affiliation_belongs_to_person
    return if affiliation.blank?
    errors.add(:affiliation, "is not one of this person's affiliations") if affiliation.person_id != person_id
  end

  # Every affiliation category except "add a new" / "other" acts on an existing row.
  def affiliation_target_present
    return if requested_value.in?([ AFFILIATION_CHANGE_ADD, AFFILIATION_CHANGE_OTHER ])
    errors.add(:affiliation_id, "must be selected") if affiliation_id.blank?
  end

  def affiliation_proposed_values
    case requested_value
    when AFFILIATION_CHANGE_TITLE
      errors.add(:proposed_title, "can't be blank") if proposed_title.blank?
    when AFFILIATION_CHANGE_DATES
      errors.add(:base, "Enter a new start or end date") if proposed_start_date.blank? && proposed_end_date.blank?
    when AFFILIATION_CHANGE_ORGANIZATION
      errors.add(:proposed_organization_name, "can't be blank") if proposed_organization_name.blank?
    when AFFILIATION_CHANGE_ADD
      errors.add(:organization_id, "must be selected") if organization_id.blank?
      errors.add(:proposed_title, "can't be blank") if proposed_title.blank?
    end
  end

  # One open request per target — per (person, field) for email/organization, and
  # per affiliation for affiliation requests, so a person can flag two different
  # affiliations at once but not stack duplicates on the same one.
  def one_pending_per_target
    scope = ProfileChangeRequest.pending
                                .where(person_id: person_id, field: field, affiliation_id: affiliation_id)
                                .where.not(id: id)
    errors.add(:base, "You already have a pending request for this.") if scope.exists?
  end
end
