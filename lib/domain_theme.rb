module DomainTheme
  # New colors must be added to the inline source in `application.tailwind.css`
  # for tailwind to generate the classes
  COLORS = {
    workshops:                :indigo,
    workshop_variations:      :purple,
    workshop_logs:            :teal,
    resources:                :violet,
    community_news:           :orange,
    stories:                  :rose,
    events:                   :blue,
    people:                   :sky,
    organizations:            :emerald,
    quotes:                   :slate,

    tags:                     :lime,
    sectors:                  :lime,
    categories:               :lime,

    faqs:                     :stone,

    workshop_ideas:           :indigo,
    workshop_variation_ideas: :purple,
    story_ideas:              :rose,
    event_registrations:      :blue,

    banners:                  :stone,
    users:                    :stone,

    admin_only:               :blue,
    user_only:                :green,

    # Badges (non-model-specific)
    legacy_facilitator:       :yellow,
    seasoned_facilitator:     :sky,
    new_facilitator:          :green,
    spotlighted_facilitator:  :gray,
    blog_contributor:         :orange
  }

  def self.color_for(key)
    COLORS[key.to_sym] || :gray
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
