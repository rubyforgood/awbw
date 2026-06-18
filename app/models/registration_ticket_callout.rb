class RegistrationTicketCallout < ApplicationRecord
  # "Action" callouts prompt the registrant to do something (download a form,
  # pay a balance); "Reference" callouts are informational reading (policies, CE
  # requirements). The distinction drives the default icon/colour and lets us
  # group them on the ticket later.
  CALLOUT_TYPES = %w[ action reference ].freeze

  # Colour themes keyed by a short name stored in `color_class`. Every utility is
  # spelled out as a literal class so Tailwind's JIT scan picks it up — never
  # interpolate the colour into a class name. Used for the icon today; the border
  # and background are here so we can tint the whole box later without a migration.
  COLOR_THEMES = {
    "amber" => { icon: "text-amber-500", border: "border-amber-300", bg: "bg-amber-50", hover: "hover:bg-amber-100", title: "text-amber-900", subtitle: "text-amber-700" },
    "indigo" => { icon: "text-indigo-500", border: "border-indigo-300", bg: "bg-indigo-50", hover: "hover:bg-indigo-100", title: "text-indigo-900", subtitle: "text-indigo-700" },
    "blue" => { icon: "text-blue-500", border: "border-blue-200", bg: "bg-blue-50", hover: "hover:bg-blue-100", title: "text-blue-900", subtitle: "text-blue-700" },
    "green" => { icon: "text-green-500", border: "border-green-300", bg: "bg-green-50", hover: "hover:bg-green-100", title: "text-green-900", subtitle: "text-green-700" },
    "purple" => { icon: "text-purple-500", border: "border-purple-300", bg: "bg-purple-50", hover: "hover:bg-purple-100", title: "text-purple-900", subtitle: "text-purple-700" },
    "rose" => { icon: "text-rose-500", border: "border-rose-300", bg: "bg-rose-50", hover: "hover:bg-rose-100", title: "text-rose-900", subtitle: "text-rose-700" },
    "gray" => { icon: "text-gray-500", border: "border-gray-200", bg: "bg-gray-50", hover: "hover:bg-gray-100", title: "text-gray-900", subtitle: "text-gray-600" }
  }.freeze

  DEFAULT_ICONS = { "action" => "fa-solid fa-arrow-right", "reference" => "fa-solid fa-circle-info" }.freeze
  DEFAULT_COLORS = { "action" => "blue", "reference" => "indigo" }.freeze

  belongs_to :event

  # Per-event ordering, drag-reordered after save via the shared `sortable`
  # Stimulus controller (a per-row PUT to #update). The gem reflows the other
  # callouts' positions on each move, exactly like Category. It assigns position
  # after validations, so position must allow nil here.
  positioned on: :event_id

  validates :title, presence: true
  validates :callout_type, inclusion: { in: CALLOUT_TYPES }
  validates :color_class, inclusion: { in: COLOR_THEMES.keys }, allow_blank: true
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

  # The colour theme hash for this callout, falling back to the per-type default.
  def theme
    key = color_class.presence || DEFAULT_COLORS.fetch(callout_type, "indigo")
    COLOR_THEMES.fetch(key, COLOR_THEMES["indigo"])
  end

  def to_s
    title
  end
end
