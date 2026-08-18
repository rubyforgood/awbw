module DomainTheme
  # New colors must be added to the inline source in `application.tailwind.css`
  # for tailwind to generate the classes
  COLORS = {
    workshops:                :indigo,
    workshop_variations:      :purple,
    workshop_logs:            :teal,
    resources:                :violet,
    community_news:           :orange,
    stories:                  :fuchsia,
    events:                   :teal,
    people:                   :cyan,
    organizations:            :emerald,
    quotes:                   :slate,
    grants:                   :green,

    tags:                     :lime,
    sectors:                  :lime,
    categories:               :lime,
    category_types:            :lime,

    forms:                    :purple,
    faqs:                     :pink,
    video_recordings:         :sky,

    workshop_ideas:           :indigo,
    workshop_variation_ideas: :purple,
    story_ideas:              :fuchsia,
    event_registrations:      :teal,

    banners:                  :yellow,
    users:                    :rose,
    notifications:            :sky,
    comments:                 :purple,
    topic_subscriptions:      :stone,
    topic_subscription_types: :stone,
    memberships:              :orange,

    # Event dashboard cards
    payments:                 :green,
    scholarships:             :fuchsia,
    continuing_education:     :teal,
    continuing_education_registrations: :teal,
    bulk_payments:            :amber,
    event_dashboard:          :indigo,
    addresses:                :slate,

    admin_only:               :blue,
    user_only:                :amber,
    person_bio:               :purple,

    # Per-event program status badges — New is indigo (not green) so it never
    # collides with the org-wide "Active" status (amber is reserved for warnings).
    program_new:              :indigo,
    program_ongoing:          :blue,
    program_reinstated:       :purple,

    # Org-wide program status (the stored organization_status): Active is the
    # positive current state, Formerly active a lapsed one, Never active neutral.
    org_active:               :green,
    org_formerly_active:      :orange,
    org_never_active:         :gray,

    # Badges (non-model-specific)
    legacy_facilitator:       :yellow,
    seasoned_facilitator:     :sky,
    new_facilitator:          :green,
    spotlighted_facilitator:  :pink,
    blog_contributor:         :orange,
    affiliated_person:        :slate
  }

  # Ordered palette of colours offered as user-pickable swatches (e.g. the
  # callout colour dropdown). A curated subset of the full theme palette that
  # reads well as tinted boxes — add a colour here once and every picker updates.
  SWATCH_COLORS = %i[ amber orange indigo blue teal green purple fuchsia rose gray ].freeze

  # Semantic roles for a colour "swatch" — the full set of Tailwind utilities for
  # tinting a boxed UI element (callout cards today; the amount-due / scholarship
  # boxes, etc. tomorrow). Each role is a single intensity off one base colour, so
  # the app's box-theming lives here rather than scattered across models and views.
  # The literal classes these produce are safelisted via the @source inline(...)
  # block in application.tailwind.css — change an intensity here and update it there.
  SWATCH_ROLES = {
    icon:     "text-%<color>s-500",
    border:   "border-%<color>s-300",
    bg:       "bg-%<color>s-50",
    hover:    "hover:bg-%<color>s-100",
    title:    "text-%<color>s-900",
    subtitle: "text-%<color>s-700"
  }.freeze

  def self.color_for(key)
    COLORS[key.to_sym] || :gray
  end

  # Full colour swatch (role => Tailwind class) for a raw base colour.
  def self.swatch(color)
    SWATCH_ROLES.transform_values { |template| format(template, color:) }
  end

  # Full colour swatch for a domain key, resolving the key to its theme colour
  # first (e.g. swatch_for(:scholarships) tints a box with the scholarships colour).
  def self.swatch_for(key)
    swatch(color_for(key))
  end

  # Every pickable swatch keyed by colour name — handy for serialising the whole
  # palette to JS (e.g. the callout editor's live colour preview).
  def self.swatches
    SWATCH_COLORS.index_with { |color| swatch(color) }
  end

  def self.bg_class_for(key, intensity: 50, hover: false)
    color = color_for(key) || :gray
    prefix = hover ? "hover:bg" : "bg"
    intensity = hover ? (intensity == 50 ? 100 : intensity + 100) : intensity
    "#{prefix}-#{color}-#{intensity}"
  end

  def self.text_class_for(key, intensity: 800)
    "text-#{color_for(key)}-#{intensity}"
  end

  def self.border_class_for(key, intensity: 300)
    "border-#{color_for(key)}-#{intensity}"
  end
end
