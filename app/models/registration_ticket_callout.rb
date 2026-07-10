class RegistrationTicketCallout < ApplicationRecord
  # "Action" callouts prompt the registrant to do something (download a form,
  # pay a balance); "Reference" callouts are informational reading (policies, CE
  # requirements). The distinction drives the default icon/colour and lets us
  # group them on the ticket later.
  CALLOUT_TYPES = %w[ action reference ].freeze

  # Hidden identifiers for the built-in ("magic") callouts. A row carrying one of
  # these was seeded from a code-defined default (see DefaultTicketCallouts) and
  # keeps its ticket behavior — badges, per-registration visibility — driven by
  # that key. Admin-authored callouts have a nil magic_key. Magic callouts are
  # hidden rather than destroyed so they can be restored to their default.
  MAGIC_KEYS = %w[
    payment certificate scholarship ce_hours event_details
    videoconference forms handouts faq
  ].freeze

  # "Content" magic callouts render their own editable copy/resources (like custom
  # callouts). "Behavioral" magic callouts (the rest) render live per-registration
  # status through MagicTicketCallouts#card_for — the row still owns the editable
  # title/subtitle/text, order, visibility, and resources.
  CONTENT_MAGIC_KEYS = %w[ handouts faq ].freeze

  # Behavioral built-ins that also carry event-level config edited inline in their
  # row (CE hours offered / cost); their text lives on the row like everything else.
  CONFIG_MAGIC_KEYS = %w[ ce_hours ].freeze

  # Per-type fallbacks for the icon and colour. These are callout-specific (unlike
  # the generic colour swatches and palette, which live in DomainTheme so the whole
  # app can reuse them for tinted boxes — amount-due, scholarship box, etc.).
  DEFAULT_ICONS = { "action" => "fa-solid fa-arrow-right", "reference" => "fa-solid fa-circle-info" }.freeze
  DEFAULT_COLORS = { "action" => "orange", "reference" => "indigo" }.freeze

  # New callouts start with the arrow icon pre-filled (the "action" default) so
  # admins see a sensible value rather than an empty field. Loaded records keep
  # their stored value; a blank one still falls back via #display_icon_class.
  attribute :icon_class, :string, default: -> { DEFAULT_ICONS["action"] }

  belongs_to :event

  # A callout can link many resources, shown in order on its detail page (PDF
  # previews + download buttons) beneath its own title/subtitle/content — e.g.
  # the Handouts card's worksheets, or a custom callout's supporting documents.
  has_many :registration_ticket_callout_resources, -> { ordered }, dependent: :destroy,
           inverse_of: :registration_ticket_callout
  has_many :resources, through: :registration_ticket_callout_resources

  # Linked resources are added one dropdown at a time in the editor (cocoon
  # add/remove), like Sectors on a Person. Blank picks are dropped.
  accepts_nested_attributes_for :registration_ticket_callout_resources, allow_destroy: true,
    reject_if: proc { |attrs| attrs["resource_id"].blank? }

  # Per-event ordering, drag-reordered after save via the shared `sortable`
  # Stimulus controller (a per-row PUT to #update). The gem reflows the other
  # callouts' positions on each move, exactly like Category. It assigns position
  # after validations, so position must allow nil here.
  positioned on: :event_id

  validates :title, presence: true
  validates :callout_type, inclusion: { in: CALLOUT_TYPES }
  validates :color_class, inclusion: { in: DomainTheme::SWATCH_COLORS.map(&:to_s) }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :magic_key, inclusion: { in: MAGIC_KEYS }, allow_nil: true
  validates :magic_key, uniqueness: { scope: :event_id }, allow_nil: true

  scope :ordered, -> { order(:position, :id) }
  scope :visible, -> { where(hidden: false) }
  scope :magic, -> { where.not(magic_key: nil) }
  scope :custom, -> { where(magic_key: nil) }

  def action?
    callout_type == "action"
  end

  # The editor exposes visibility as "Published" — the inverse of the stored
  # `hidden` flag — so a checked box means the callout shows on the ticket.
  def published
    !hidden
  end
  alias_method :published?, :published

  def published=(value)
    self.hidden = !ActiveModel::Type::Boolean.new.cast(value)
  end

  # A seeded built-in callout (Handouts, FAQ, …) rather than an admin-authored
  # one. Magic callouts hide instead of delete and can be reset to default.
  def magic?
    magic_key.present?
  end

  # A behavioral built-in callout whose card is rendered by MagicTicketCallouts
  # (live status), as opposed to a content callout that renders from its own row.
  def behavioral_magic?
    magic? && CONTENT_MAGIC_KEYS.exclude?(magic_key)
  end

  # Whether the row carries the inline CE config fields (hours offered / cost).
  def ce_config?
    CONFIG_MAGIC_KEYS.include?(magic_key.to_s)
  end

  # Whether the callout is drip-scheduled to appear only from a future date.
  def dripping?(now = Time.current)
    display_from.present? && display_from > now
  end

  # Font Awesome class for the leading icon, falling back to a sensible default
  # per callout type so a callout never renders without an icon.
  def display_icon_class
    icon_class.presence || DEFAULT_ICONS.fetch(callout_type, DEFAULT_ICONS["reference"])
  end

  # The colour swatch (icon/border/bg/hover/title/subtitle classes) for this
  # callout, falling back to the per-type default colour.
  def theme
    color = color_class.presence || DEFAULT_COLORS.fetch(callout_type, "indigo")
    DomainTheme.swatch(color)
  end

  def to_s
    title
  end
end
