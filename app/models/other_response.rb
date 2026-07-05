class OtherResponse < ApplicationRecord
  # The free-text "Other" a person typed on a tag-backed form question. Only
  # sectors are wired up today; the `kind` column leaves room for the identical
  # workshop-setting responses to move here later.
  KINDS = %w[sector].freeze

  # A response starts life as `pending` (awaiting a curator's decision) and is
  # then either promoted into a real tag, kept as a free-text chip, or dismissed
  # (hidden from the person's profile and edit form).
  STATUSES = %w[pending kept promoted dismissed].freeze

  # Statuses that still surface as an "(other)" chip on the person's pages.
  VISIBLE_STATUSES = %w[pending kept].freeze

  belongs_to :person
  belongs_to :promotable, polymorphic: true, optional: true
  belongs_to :source_form_answer, class_name: "FormAnswer", optional: true

  before_validation :set_normalized_text

  validates :text, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :normalized_text, uniqueness: { scope: [ :person_id, :kind ] }

  scope :sectors, -> { where(kind: "sector") }
  scope :visible, -> { where(status: VISIBLE_STATUSES) }
  scope :pending, -> { where(status: "pending") }
  scope :promotable_now, -> { where.not(status: "dismissed") }

  # Case/whitespace-insensitive key used both for the unique index and for
  # grouping the same typed value across many people on the review page.
  def self.normalize(value)
    value.to_s.strip.downcase
  end

  def dismiss!
    update!(status: "dismissed")
  end

  def keep!
    update!(status: "kept")
  end

  private

  def set_normalized_text
    self.normalized_text = self.class.normalize(text)
  end
end
