class OtherResponse < ApplicationRecord
  # A free-text "Other" someone typed on a form question whose "Other" can (or
  # will) become a real tag. Captured at submission time so a curator can
  # promote / keep / dismiss it. The `owner` is polymorphic because the answer's
  # subject differs by question: a sector "Other" is about the person, an
  # organization-type "Other" is about their organization.
  #
  # - `sector`            → owned by a Person; promotable into a `Sector`, shown
  #                         on the person's profile beside the sector tags.
  # - `organization_type` → owned by an Organization; stored now, but not yet
  #                         promotable (its promote button is hidden until
  #                         `OrganizationType` is a model).
  #
  # Questions whose "Other" will never become a tag (`generic`) are not captured
  # at all — that data stays searchable in the form answers.
  KINDS = %w[sector organization_type generic].freeze

  # Kinds we materialize as records (the rest stay in the form answers).
  CAPTURED_KINDS = %w[sector organization_type].freeze

  # Kinds captured against a Person, via their form submission.
  PERSON_KINDS = %w[sector].freeze

  # Kinds that can be promoted into a real tag today.
  PROMOTABLE_KINDS = %w[sector].freeze

  # The organization-type question. Its "Other" is org-owned (see
  # PublicRegistration#sync_agency_type).
  ORGANIZATION_TYPE_FIELD_IDENTIFIER = "agency_type"

  # A response starts life as `pending` (awaiting a curator's decision) and is
  # then either promoted into a real tag, kept as auxiliary data, or dismissed.
  STATUSES = %w[pending kept promoted dismissed].freeze

  # Statuses that still surface (as an "(other)" chip for sectors, or a live row
  # in the review queue).
  VISIBLE_STATUSES = %w[pending kept].freeze

  belongs_to :owner, polymorphic: true
  belongs_to :promotable, polymorphic: true, optional: true
  belongs_to :source_form_answer, class_name: "FormAnswer", optional: true

  before_validation :set_kind
  before_validation :set_normalized_text

  validates :field_identifier, presence: true
  validates :text, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :normalized_text, uniqueness: { scope: [ :owner_type, :owner_id, :field_identifier ] }

  scope :sectors, -> { where(kind: "sector") }
  scope :visible, -> { where(status: VISIBLE_STATUSES) }
  scope :pending, -> { where(status: "pending") }
  scope :promotable_now, -> { where.not(status: "dismissed") }

  # The coarse category (and thus owner + promotability) for a question.
  def self.kind_for(field_identifier)
    identifier = field_identifier.to_s
    if identifier.in?(FormField::SECTOR_FIELD_IDENTIFIERS)
      "sector"
    elsif identifier == ORGANIZATION_TYPE_FIELD_IDENTIFIER
      "organization_type"
    else
      "generic"
    end
  end

  # Case/whitespace-insensitive key used both for the unique index and for
  # grouping the same typed value across owners on the review page.
  def self.normalize(value)
    value.to_s.strip.downcase
  end

  # Stable DOM id for a review-page group, so a chip can deep-link to its row.
  def self.review_anchor(bucket, normalized_text)
    "other-#{bucket}-#{normalized_text}".parameterize
  end

  def promotable?
    kind.in?(PROMOTABLE_KINDS)
  end

  # The organization(s) the person registered with when they typed this response,
  # derived from the source form answer's submission + the person's registration
  # for that event. Lets promotion mirror a sector onto exactly the orgs a
  # registration would have — no need to store the org here. Empty when there's no
  # registration context (no source answer, or a non-person owner).
  def registration_organizations
    event = source_form_answer&.form_submission&.event
    return Organization.none unless event && owner.is_a?(Person)

    owner.event_registrations.find_by(event: event)&.organizations || Organization.none
  end

  # How the review page buckets this response: captured kinds group by kind (all
  # sector "Other"s together, all org-type together); generic groups by question.
  def group_key
    kind == "generic" ? field_identifier : kind
  end

  def review_anchor
    self.class.review_anchor(group_key, normalized_text)
  end

  def dismiss!
    update!(status: "dismissed")
  end

  def keep!
    update!(status: "kept")
  end

  private

  def set_kind
    self.kind = self.class.kind_for(field_identifier) if field_identifier.present?
  end

  def set_normalized_text
    self.normalized_text = self.class.normalize(text)
  end
end
