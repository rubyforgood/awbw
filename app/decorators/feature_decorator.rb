class FeatureDecorator < ApplicationDecorator
  delegate_all

  def area_meta
    Feature::AREAS_BY_KEY.fetch(area, DEFAULT_AREA)
  end

  def area_label
    area_meta[:label]
  end

  def area_icon
    area_meta[:icon]
  end

  def area_color
    area_meta[:color]
  end

  GITHUB_REPO = "rubyforgood/awbw".freeze

  # Link to the GitHub PR the feature shipped in, or nil when unknown.
  def pr_url
    return if pr_number.blank?

    "https://github.com/#{GITHUB_REPO}/pull/#{pr_number}"
  end

  # The "Check out this feature" destination. Record-scoped pages are seeded with
  # the sample id 1 (e.g. /events/1/registrants); when no such record exists we
  # fall back to that resource's index (/events) so the link never 404s on a
  # fresh or differently-keyed database.
  def resolved_action_url
    path = action_path.to_s
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

  # e.g. "Aug 9, 2026" — plain, friendly, no ordinal.
  def released_label
    released_on&.strftime("%b %-d, %Y")
  end

  # ISO date (yyyy-mm-dd) for the client-side date-range filter and sort. Because
  # it's zero-padded, lexical string comparison in JS orders chronologically.
  def released_iso
    released_on&.iso8601
  end

  # Lowercased haystack the page's search box matches against — name, summary,
  # pro tips, area, and audience label.
  def search_text
    [ name, summary, *pro_tips_list, area_label, status_label ].join(" ").downcase
  end

  # Area badge (icon + label), tinted with the area's theme colour.
  def area_badge
    badge(area_icon, area_label, area_meta[:color])
  end

  # Audience badge (icon + label), tinted with the audience's colour.
  def status_badge
    badge(status_icon, status_label, status_meta[:color])
  end

  private

  DEFAULT_AREA = { key: "other", label: "More", icon: "fa-star", color: "gray" }.freeze
  DEFAULT_STATUS = { label: "Feature", icon: "fa-star", color: "gray" }.freeze

  def badge(icon, label, color)
    classes = h.badge_classes("bg-#{color}-100 text-#{color}-800 border-#{color}-200")
    h.content_tag(:span, class: classes) do
      h.safe_join([ h.content_tag(:i, "", class: "fa-solid #{icon}"), label ], " ")
    end
  end
end
