class FeatureDecorator < ApplicationDecorator
  delegate_all

  def area_meta
    Feature::AREAS_BY_KEY.fetch(area, DEFAULT_AREA)
  end

  def area_label
    area_meta[:label]
  end

  def area_icon
    area_meta[:icon] || ApplicationHelper::INDEX_BUTTON_ICONS[area_meta[:domain]]
  end

  def area_color
    area_meta[:color] || DomainTheme.color_for(area_meta[:domain]).to_s
  end

  GITHUB_REPO = "rubyforgood/awbw".freeze

  def pr_url
    return if pr_number.blank?

    "https://github.com/#{GITHUB_REPO}/pull/#{pr_number}"
  end

  TICKET_PATH = "/registration/sample".freeze

  # TICKET_PATH → a live/sample ticket; a `/…/1/…` path falls back to that
  # resource's index when id 1 is absent, so the link never 404s.
  def resolved_action_url
    path = action_path.to_s
    return ticket_url if path == TICKET_PATH
    return action_path if path.blank?

    match = path.match(%r{\A/(?<resource>[a-z_]+)/1(?:/|\z)})
    return action_path unless match

    model = match[:resource].classify.safe_constantize
    return action_path if model.respond_to?(:exists?) && model.exists?(1)

    "/#{match[:resource]}"
  end

  def status_meta
    Feature::DISPLAY_STATUSES.fetch(display_status, DEFAULT_STATUS)
  end

  def status_label
    status_meta[:label]
  end

  def status_icon
    status_meta[:icon]
  end

  def released_label
    released_on&.strftime("%b %-d, %Y")
  end

  def area_badge
    badge(area_icon, area_label, area_color)
  end

  def status_badge
    badge(status_icon, status_label, status_meta[:color])
  end

  private

  DEFAULT_AREA = { key: "other", label: "More", icon: "fa-star", color: "gray" }.freeze
  DEFAULT_STATUS = { label: "Feature", icon: "fa-star", color: "gray" }.freeze

  def ticket_url
    registration = EventRegistration.where.not(slug: [ nil, "" ]).first
    return h.registration_ticket_path(registration.slug) if registration

    event = Event.first
    event ? h.sample_ticket_event_path(event) : h.events_path
  end

  def badge(icon, label, color)
    classes = h.badge_classes("bg-#{color}-100 text-#{color}-800 border-#{color}-200")
    h.content_tag(:span, class: classes) do
      h.safe_join([ h.content_tag(:i, "", class: "fa-solid #{icon}"), label ], " ")
    end
  end
end
