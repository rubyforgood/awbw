class ProfileChangeRequest < ApplicationRecord
  belongs_to :person
  belongs_to :requested_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true
  # The specific records a request targets, snapshotted at submission so a later
  # change to the person's affiliations can't move the target out from under it.
  belongs_to :organization, optional: true
  belongs_to :affiliation, optional: true
  belongs_to :professional_license, optional: true

  OTHER_FIELD = "other".freeze
  LICENSE_FIELD = "professional_license".freeze
  EMAIL_FIELDS = %w[primary_email secondary_email].freeze
  FIELDS = [ *EMAIL_FIELDS, "organization_name", "affiliation", LICENSE_FIELD, OTHER_FIELD ].freeze
  FIELD_LABELS = {
    "primary_email" => "Primary email",
    "secondary_email" => "Secondary email",
    "organization_name" => "Organization name",
    "affiliation" => "Affiliation details",
    LICENSE_FIELD => "Professional license",
    OTHER_FIELD => "Profile data"
  }.freeze
  # Fields whose new value is concrete enough for "Approve" to write directly.
  AUTO_APPLIABLE_FIELDS = [ *EMAIL_FIELDS, "organization_name" ].freeze
  STATUSES = %w[pending resolved declined].freeze
  RESOLUTION_METHODS = %w[approved manual].freeze
  # What an affiliation request is asking to change (stored in requested_value),
  # so the person picks a structured category rather than only free text.
  AFFILIATION_CHANGE_TITLE = "Title or role".freeze
  AFFILIATION_CHANGE_DATES = "Start or end dates".freeze
  AFFILIATION_CHANGE_ORGANIZATION = "Organization".freeze
  AFFILIATION_CHANGE_REMOVE = "Remove this affiliation".freeze
  AFFILIATION_CHANGE_ADD = "Add a new affiliation".freeze
  AFFILIATION_CHANGE_WORK_ADDRESS = "Work address".freeze
  AFFILIATION_CHANGE_OTHER = "Other".freeze
  AFFILIATION_CHANGE_TYPES = [
    AFFILIATION_CHANGE_TITLE,
    AFFILIATION_CHANGE_DATES,
    AFFILIATION_CHANGE_ORGANIZATION,
    AFFILIATION_CHANGE_REMOVE,
    AFFILIATION_CHANGE_ADD,
    AFFILIATION_CHANGE_WORK_ADDRESS,
    AFFILIATION_CHANGE_OTHER
  ].freeze
  # These carry a structured value Approve can apply directly. "Work address" and
  # "Other" are free text an admin handles by hand.
  AFFILIATION_AUTO_CATEGORIES = (AFFILIATION_CHANGE_TYPES - [ AFFILIATION_CHANGE_WORK_ADDRESS, AFFILIATION_CHANGE_OTHER ]).freeze

  validates :field, inclusion: { in: FIELDS }
  validates :status, inclusion: { in: STATUSES }
  validates :resolution_method, inclusion: { in: RESOLUTION_METHODS }, allow_nil: true
  validates :requested_value, presence: true, unless: -> { other? || license? }
  validates :requested_value, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" },
                              if: -> { field.in?(EMAIL_FIELDS) && requested_value.present? }
  validates :proposed_email_type, inclusion: { in: Person::CONTACT_TYPES }, allow_blank: true
  validates :details, presence: true, if: :requires_details?
  validate :email_request_changes_something, if: -> { pending? && email? }
  validate :affiliation_belongs_to_person
  validate :professional_license_belongs_to_person
  validates :professional_license, presence: true, if: :license?
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
  def other? = field == OTHER_FIELD
  def license? = field == LICENSE_FIELD
  def email? = field.in?(EMAIL_FIELDS)

  def auto_appliable?
    return true if field.in?(AUTO_APPLIABLE_FIELDS)
    field == "affiliation" && requested_value.in?(AFFILIATION_AUTO_CATEGORIES) && !new_organization?
  end

  # An add request for an organization that isn't in the portal yet — staff create it by hand.
  def new_organization?
    requested_value == AFFILIATION_CHANGE_ADD && organization_id.blank? && proposed_organization_name.present?
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
    when AFFILIATION_CHANGE_ADD then [ proposed_title, organization&.name || new_organization_label, proposed_dates_label ].compact_blank.join(" · ")
    end
  end

  def new_organization_label
    "#{proposed_organization_name} (not in the portal yet)" if new_organization?
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
    when "secondary_email" then person.email_2
    when "organization_name" then target_organization&.name
    when LICENSE_FIELD then professional_license&.decorate&.summary
    end
  end

  def current_email_type
    case field
    when "primary_email" then person.email_type.presence || person.user&.email_type
    when "secondary_email" then person.email_2_type
    end
  end

  # Starts an email request from what's on file, so asking to change only the type
  # doesn't mean retyping the address.
  def prefill_current_email
    return unless email?

    self.requested_value ||= current_value
    self.proposed_email_type ||= current_email_type
  end

  # A one-line description of the affiliation an affiliation request targets.
  def affiliation_summary
    return unless affiliation

    org = affiliation.organization&.name
    [ affiliation.decorate.display_title, org ].compact.join(" @ ")
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
    other? || license? || (field == "affiliation" && requested_value.in?([ AFFILIATION_CHANGE_WORK_ADDRESS, AFFILIATION_CHANGE_OTHER ]))
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
    self.proposed_organization_name = nil unless requested_value.in?([ AFFILIATION_CHANGE_ORGANIZATION, AFFILIATION_CHANGE_ADD ])
    self.proposed_organization_name = nil if requested_value == AFFILIATION_CHANGE_ADD && organization_id.present?
  end

  def affiliation_belongs_to_person
    return if affiliation.blank?
    errors.add(:affiliation, "is not one of this person's affiliations") if affiliation.person_id != person_id
  end

  def email_request_changes_something
    return if requested_value.blank?
    return unless requested_value.casecmp?(current_value.to_s)
    return if proposed_email_type.present? && proposed_email_type != current_email_type

    errors.add(:base, "That's already what's on file. Change the address or its type.")
  end

  def professional_license_belongs_to_person
    return if professional_license.blank?
    errors.add(:professional_license, "is not one of this person's licenses") if professional_license.person_id != person_id
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
      errors.add(:base, "Pick an organization, or type its name if it's not on the list") if organization_id.blank? && proposed_organization_name.blank?
      errors.add(:proposed_title, "can't be blank") if proposed_title.blank?
    end
  end

  # One open request per target — per (person, field) for email/organization, and
  # per affiliation or license for those requests, so a person can flag two
  # different affiliations at once but not stack duplicates on the same one.
  def one_pending_per_target
    scope = ProfileChangeRequest.pending
                                .where(person_id: person_id, field: field, affiliation_id: affiliation_id,
                                       professional_license_id: professional_license_id)
                                .where.not(id: id)
    errors.add(:base, "You already have a pending request for this.") if scope.exists?
  end
end
