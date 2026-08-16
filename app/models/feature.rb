class Feature < ApplicationRecord
  # `rhino_`-prefixed per the app's ActionText/Rhino convention (see rhino_editor helper).
  has_rich_text :rhino_description

  # Colour + icon resolve from the `domain` key (DomainTheme + INDEX_BUTTON_ICONS);
  # content/reporting have no domain, so they set a manual colour + icon.
  AREAS = [
    { key: "events",         label: "Events & trainings",     domain: :events },
    { key: "registration",   label: "Registration & tickets", domain: :event_registrations },
    { key: "scholarships",   label: "Scholarships & grants",   domain: :scholarships },
    { key: "payments",       label: "Payments & billing",     domain: :payments },
    { key: "people",         label: "People & organizations", domain: :people },
    { key: "content",        label: "Workshops & resources",  color: "indigo", icon: "fa-palette" },
    { key: "stories",        label: "Stories & community",    domain: :stories },
    { key: "communications", label: "Communications",         domain: :notifications },
    { key: "reporting",      label: "Reporting & admin",      color: "slate", icon: "fa-chart-line" }
  ].freeze

  AREAS_BY_KEY = AREAS.index_by { |area| area[:key] }.freeze
  AREA_KEYS = AREAS.map { |area| area[:key] }.freeze

  # Audience that also gates visibility (`admin_facing` = super-admins only).
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
  validates :action_path, format: { with: %r{\A(/|https?://)[^\n]*\z},
                                     message: "must be a path (/…) or a URL" }, allow_blank: true
  validates :pr_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :published, -> { where(published: true) }
  scope :readable_by_non_admins, -> { where.not(display_status: ADMIN_ONLY_STATUS) }
  scope :by_release, -> { order(released_on: :desc, name: :asc) }

  def pro_tips_list
    pro_tips.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  def admin_only?
    display_status == ADMIN_ONLY_STATUS
  end
end
