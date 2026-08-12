class Feature < ApplicationRecord
  # Full, screenshot-friendly write-up edited in the Rhino WYSIWYG. The card
  # summary is the short version; this is the long one. (`rhino_`-prefixed per
  # the app's ActionText convention — see rhino_editor helper.)
  has_rich_text :rhino_description

  # Ordered area taxonomy — the single source of truth for a feature's grouping.
  # `color` is a Tailwind hue already safelisted in application.tailwind.css (via
  # DomainTheme's @source inline block), so the tinted `bg-<color>-100` /
  # `text-<color>-800` classes render. `icon` is a Font Awesome name. Presentation
  # (labels/badges) lives on FeatureDecorator; this is just the data.
  AREAS = [
    { key: "events",         label: "Events & trainings",       icon: "fa-calendar-days",      color: "teal" },
    { key: "registration",   label: "Registration & tickets",   icon: "fa-ticket",             color: "amber" },
    { key: "scholarships",   label: "Scholarships & grants",    icon: "fa-graduation-cap",     color: "fuchsia" },
    { key: "payments",       label: "Payments & billing",       icon: "fa-money-check-dollar", color: "green" },
    { key: "people",         label: "People & organizations",   icon: "fa-user-group",         color: "cyan" },
    { key: "content",        label: "Workshops & resources",    icon: "fa-palette",            color: "indigo" },
    { key: "stories",        label: "Stories & community",      icon: "fa-book-open",          color: "orange" },
    { key: "communications", label: "Communications",           icon: "fa-bell",               color: "sky" },
    { key: "reporting",      label: "Reporting & admin",        icon: "fa-chart-line",         color: "slate" }
  ].freeze

  AREAS_BY_KEY = AREAS.index_by { |area| area[:key] }.freeze
  AREA_KEYS = AREAS.map { |area| area[:key] }.freeze

  # Audience of a feature — both a label shown on the page and the visibility
  # gate. `admin_facing` is restricted to super-admins by FeaturePolicy; the
  # others are visible to any signed-in user. Plain string column constrained by
  # a constant + inclusion (no Rails enum), per CLAUDE.md.
  DISPLAY_STATUSES = {
    "public_facing" => { label: "Public-facing",   icon: "fa-globe", color: "green" },
    "user_facing"   => { label: "For facilitators", icon: "fa-user",  color: "blue" },
    "admin_facing"  => { label: "Admin-facing",     icon: "fa-lock",  color: "slate" }
  }.freeze
  DISPLAY_STATUS_KEYS = DISPLAY_STATUSES.keys.freeze
  ADMIN_ONLY_STATUS = "admin_facing".freeze

  validates :name, presence: true, length: { maximum: 150 }
  validates :summary, presence: true, length: { maximum: 300 }
  validates :area, inclusion: { in: AREA_KEYS }
  validates :display_status, inclusion: { in: DISPLAY_STATUS_KEYS }
  validates :released_on, presence: true
  validates :external_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                                     message: "must start with http:// or https://" }, allow_blank: true
  # In-app destination for the "Check out this feature" link on the detail page —
  # a relative path ("/events") or a full URL.
  validates :action_path, format: { with: %r{\A(/|https?://)[^\n]*\z},
                                     message: "must be a path (/…) or a URL" }, allow_blank: true
  # GitHub PR the feature shipped in (adds a "View the pull request" link).
  validates :pr_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :published, -> { where(published: true) }
  scope :readable_by_non_admins, -> { where.not(display_status: ADMIN_ONLY_STATUS) }
  scope :by_release, -> { order(released_on: :desc, name: :asc) }

  # Pro tips are stored one-per-line in a text column and rendered as a list.
  def pro_tips_list
    pro_tips.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  def admin_only?
    display_status == ADMIN_ONLY_STATUS
  end
end
