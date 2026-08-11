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
