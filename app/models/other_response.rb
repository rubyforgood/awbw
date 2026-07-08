class OtherResponse < ApplicationRecord
  # A free-text "Other" a person typed on any tag/option-backed form question,
  # captured at submission time so a curator can promote / keep / dismiss it.
  # `field_identifier` records which question it came from; `kind` is the coarse
  # category that decides whether it can be promoted into a real tag.
  #
  # - "sector"  → the additional-sectors question; promotable into a Sector, and
  #               shown on the person's profile beside the sector tags.
  # - "generic" → any other question's "Other"; auxiliary data reviewed by admins
  #               (keep/dismiss only), never shown on a profile.
  #
  # Organization-type "Other" is deliberately NOT captured here — it belongs to
  # the organization (see PublicRegistration#sync_agency_type) and will get its
  # own promotable path once OrganizationType is a model.
  KINDS = %w[sector generic].freeze

  # Kinds that can be promoted into a real tag record.
  PROMOTABLE_KINDS = %w[sector].freeze

  # A response starts life as `pending` (awaiting a curator's decision) and is
  # then either promoted into a real tag, kept as auxiliary data, or dismissed.
  STATUSES = %w[pending kept promoted dismissed].freeze

  # Statuses that still surface (as an "(other)" chip for sectors, or a live row
  # in the review queue).
  VISIBLE_STATUSES = %w[pending kept].freeze

  belongs_to :person
  belongs_to :promotable, polymorphic: true, optional: true
  belongs_to :source_form_answer, class_name: "FormAnswer", optional: true

  before_validation :set_kind
  before_validation :set_normalized_text

  validates :field_identifier, presence: true
  validates :text, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :normalized_text, uniqueness: { scope: [ :person_id, :field_identifier ] }

  scope :sectors, -> { where(kind: "sector") }
  scope :visible, -> { where(status: VISIBLE_STATUSES) }
  scope :pending, -> { where(status: "pending") }
  scope :promotable_now, -> { where.not(status: "dismissed") }

  # The coarse category for a question. Sector fields promote into Sectors;
  # everything else is generic auxiliary data.
  def self.kind_for(field_identifier)
    field_identifier.to_s.in?(FormField::SECTOR_FIELD_IDENTIFIERS) ? "sector" : "generic"
  end

  # Case/whitespace-insensitive key used both for the unique index and for
  # grouping the same typed value across many people on the review page.
  def self.normalize(value)
    value.to_s.strip.downcase
  end

  def promotable?
    kind.in?(PROMOTABLE_KINDS)
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
