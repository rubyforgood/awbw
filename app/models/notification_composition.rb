# A saved bulk-email composition: a draft (personal, one-shot) or a reusable
# template, set by `kind`. Holds the email content plus a re-resolvable audience
# recipe. On send it fans out into Notification rows (an FYI parent + one child
# per recipient); the draft is deleted afterwards, so the composition itself is
# never the record of a sent email — that lives in `notifications`.
class NotificationComposition < ApplicationRecord
  KINDS = %w[draft template].freeze
  SCOPE_TYPES = %w[general event].freeze

  belongs_to :user
  belongs_to :event, optional: true

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :scope_type, presence: true, inclusion: { in: SCOPE_TYPES }
  # Templates are picked from a list, so they need a name; a draft is a
  # work-in-progress and may be saved before it has one.
  validates :name, presence: true, if: :template?

  scope :drafts, -> { where(kind: "draft") }
  scope :templates, -> { where(kind: "template") }

  def draft?
    kind == "draft"
  end

  def template?
    kind == "template"
  end

  def event_scoped?
    scope_type == "event"
  end

  # Presence of the content is the on/off flag for the optional email blocks —
  # there are deliberately no _enabled columns.
  def cta_button?
    cta_label.present?
  end

  def grey_box?
    grey_box_text.present?
  end

  # Audience recipe + overrides, coalesced so callers always get arrays even
  # before anything has been stored.
  def segments
    recipient_segments || []
  end

  def added_ids
    (recipient_added_ids || []).map(&:to_i)
  end

  def excluded_ids
    (recipient_excluded_ids || []).map(&:to_i)
  end
end
