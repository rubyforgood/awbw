class RegistrationTicketCallout < ApplicationRecord
  # "Action" callouts prompt the registrant to do something (download a form,
  # pay a balance); "Reference" callouts are informational reading (policies, CE
  # requirements). The distinction drives the default icon/colour and lets us
  # group them on the ticket later.
  CALLOUT_TYPES = %w[ action reference ].freeze

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

  # Optionally links the callout to a Resource. When present, the callout's
  # detail page renders the resource's display (PDF first-page preview, etc.)
  # and a download button beneath the callout's own title/subtitle/content.
  belongs_to :resource, optional: true

  # Per-event ordering, drag-reordered after save via the shared `sortable`
  # Stimulus controller (a per-row PUT to #update). The gem reflows the other
  # callouts' positions on each move, exactly like Category. It assigns position
  # after validations, so position must allow nil here.
  positioned on: :event_id

  validates :title, presence: true
  validates :callout_type, inclusion: { in: CALLOUT_TYPES }
  validates :color_class, inclusion: { in: DomainTheme::SWATCH_COLORS.map(&:to_s) }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  scope :ordered, -> { order(:position, :id) }

  def action?
    callout_type == "action"
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
