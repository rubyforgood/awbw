class EventDecorator < ApplicationDecorator
  decorates_association :bookmarkable

  def display_image
    return primary_asset.file if primary_asset&.file&.attached?

    # TODO: revisit once rhino editor embeds are confirmed to work as ActionText attachments
    # if (img = header_image)
    #   return img
    # end

    return gallery_assets.first.file if gallery_assets.first&.file&.attached?
    default_display_image
  end

  def date
    start_date.strftime("%B %d, %Y")
  end

  def detail(length: nil)
    length ? description&.truncate(length) : description
  end

  def calendar_links
    start_time   = object.start_date.strftime("%Y%m%dT%H%M%SZ")
    end_time     = object.end_date.strftime("%Y%m%dT%H%M%SZ")
    title_encoded = ERB::Util.url_encode(object.title)

    has_url      = object.videoconference_url.present?
    has_location = object.location.present?
    location_name = has_location ? object.location.name : nil

    # If both: URL in location field, physical location in description
    # If only URL: URL in location field
    # If only location: location in location field
    if has_url && has_location
      cal_location = object.videoconference_url
      description  = "#{location_name}\n\n#{object.description}"
    elsif has_url
      cal_location = object.videoconference_url
      description  = object.description.to_s
    elsif has_location
      cal_location = location_name
      description  = object.description.to_s
    else
      cal_location = nil
      description  = object.description.to_s
    end

    desc_encoded     = ERB::Util.url_encode(description)
    location_encoded = ERB::Util.url_encode(cal_location.to_s)

    google_link =
      "https://calendar.google.com/calendar/render?action=TEMPLATE" \
        "&text=#{title_encoded}&dates=#{start_time}/#{end_time}" \
        "&details=#{desc_encoded}&location=#{location_encoded}"

    apple_link =
      "data:text/calendar;charset=utf8,BEGIN:VCALENDAR\n" \
        "VERSION:2.0\n" \
        "BEGIN:VEVENT\n" \
        "SUMMARY:#{object.title}\n" \
        "DTSTART:#{start_time}\n" \
        "DTEND:#{end_time}\n" \
        "DESCRIPTION:#{description}\n" \
        "#{"LOCATION:#{cal_location}\n" if cal_location}" \
        "END:VEVENT\n" \
        "END:VCALENDAR"

    outlook_link =
      "https://outlook.live.com/owa/?rru=addevent" \
        "&startdt=#{start_time}&enddt=#{end_time}" \
        "&subject=#{title_encoded}&body=#{desc_encoded}&location=#{location_encoded}"

    office365_link =
      "https://outlook.office.com/owa/?rru=addevent" \
        "&startdt=#{start_time}&enddt=#{end_time}" \
        "&subject=#{title_encoded}&body=#{desc_encoded}&location=#{location_encoded}"

    yahoo_link =
      "https://calendar.yahoo.com/?v=60" \
        "&title=#{title_encoded}&st=#{start_time}" \
        "&et=#{end_time}&desc=#{desc_encoded}&in_loc=#{location_encoded}"

    h.safe_join(
      [
        h.link_to("Google", google_link, class: "text-blue-600 hover:underline text-xs", target: "_blank"),
        h.content_tag(:span, "•", class: "text-gray-300"),
        h.link_to("Apple", apple_link, class: "text-blue-600 hover:underline text-xs",
                  target: "_blank",
                  download: "#{object.title.parameterize}.ics"),
        h.content_tag(:span, "•", class: "text-gray-300"),
        h.link_to("Outlook", outlook_link, class: "text-blue-600 hover:underline text-xs", target: "_blank"),
        h.content_tag(:span, "•", class: "text-gray-300"),
        h.link_to("Office 365", office365_link, class: "text-blue-600 hover:underline text-xs", target: "_blank"),
        h.content_tag(:span, "•", class: "text-gray-300"),
        h.link_to("Yahoo", yahoo_link, class: "text-blue-600 hover:underline text-xs", target: "_blank")
      ],
      " "
    )
  end

  def times(display_day: false, display_date: false, inline: false, styled: false)
    s = start_date.in_time_zone(Time.zone)
    e = (end_date || start_date).in_time_zone(Time.zone)
    tz_abbr = s.strftime("%Z")
    muted = styled ? "text-lg font-normal text-blue-400" : nil

    # helpers
    day  = ->(d) { d.strftime("%a") }
    date = ->(d) { d.strftime("%b %-d") }
    full_day  = ->(d) { d.strftime("%A") }
    full_date = ->(d) { d.strftime("%B %-d") }
    wrap = ->(text, css) { css ? h.content_tag(:span, text, class: css) : text }

    format_time = lambda do |d|
      hour = d.strftime("%-l")
      min  = d.strftime("%M")
      ampm = d.strftime("%P")

      hide_min = (min == "00")

      t = hour
      t += ":#{min}" unless hide_min
      t += " #{ampm}" # <-- SPACE before am/pm
      t
    end

    parts_for = lambda do |d, prefix: nil|
      parts = []
      parts << wrap.call(prefix, muted) if prefix
      parts << "#{day.call(d)}, " if display_day
      parts << "#{date.call(d)} @ " if display_date
      parts << format_time.call(d)
      h.safe_join(parts)
    end

    tz_display = wrap.call(" #{tz_abbr}", muted)

    # --------------------------------------------------
    # STYLED → two-row layout (show page)
    # --------------------------------------------------
    if styled
      styled_tz = h.content_tag(:span, " #{tz_abbr}", class: "text-lg")

      if s.to_date != e.to_date
        # Multi-day: date range on row 1, time range on row 2
        date_line = if s.month == e.month && s.year == e.year
          "#{s.strftime('%B')} #{s.strftime('%-d')}-#{e.strftime('%-d')}, #{s.strftime('%Y')}"
        elsif s.year == e.year
          "#{s.strftime('%B %-d')} - #{e.strftime('%B %-d')}, #{s.strftime('%Y')}"
        else
          "#{s.strftime('%B %-d, %Y')} - #{e.strftime('%B %-d, %Y')}"
        end
        time_line = "#{format_time.call(s)} - #{format_time.call(e)}"
        return h.safe_join([ date_line, h.tag.br, time_line, styled_tz ])
      else
        # Same day: date on row 1, time range on row 2
        date_line = "#{full_day.call(s)}, #{full_date.call(s)}"
        same_exact_time = (s.hour == e.hour) && (s.min == e.min)
        time_line = if same_exact_time
          "#{format_time.call(s)}"
        else
          "#{format_time.call(s)} - #{format_time.call(e)}"
        end
        return h.safe_join([ date_line, h.tag.br, time_line, styled_tz ])
      end
    end

    # --------------------------------------------------
    # DIFFERENT DAY → two lines
    # --------------------------------------------------
    if s.to_date != e.to_date
      if inline
        return h.safe_join(
          [ parts_for.call(s), h.safe_join([ parts_for.call(e), tz_display ]) ],
          " - "
        )
      else
        return h.safe_join(
          [ parts_for.call(s), h.safe_join([ parts_for.call(e), tz_display ]) ],
          h.tag.br
        )
      end
    end

    # --------------------------------------------------
    # SAME DAY → one line unless times differ
    # --------------------------------------------------
    same_exact_time = (s.hour == e.hour) && (s.min == e.min)

    parts = []
    parts << "#{day.call(s)}, " if display_day
    parts << "#{date.call(s)} @ " if display_date

    if same_exact_time
      # Only one time
      parts << format_time.call(s)
    else
      s_hour = s.strftime("%-l")
      s_min  = s.strftime("%M")
      s_ampm = s.strftime("%P")

      e_hour = e.strftime("%-l")
      e_min  = e.strftime("%M")
      e_ampm = e.strftime("%P")

      hide_start_min  = (s_min == "00")
      hide_end_min    = (e_min == "00")
      hide_start_ampm = (s_ampm == e_ampm)

      # Start
      start_time = s_hour.dup
      start_time << ":#{s_min}" unless hide_start_min
      start_time << " #{s_ampm}" unless hide_start_ampm

      # End
      end_time = e_hour.dup
      end_time << ":#{e_min}" unless hide_end_min
      end_time << " #{e_ampm}"

      parts << "#{start_time} - #{end_time}"
    end

    parts << tz_display
    h.safe_join(parts)
  end

  def breadcrumbs
    "#{bookmarks_link} >> #{bookmarkable_link}".html_safe
  end

  def labelled_cost
    return if cost_cents.blank? || cost_cents.zero?

    "Cost: $#{cost}"
  end

  def content
    if bookmarkable_class_name == "Workshop"
      h.render "/workshops/show", workshop: bookmarkable, sectors: bookmarkable.sectors,
                                       new_bookmark: bookmarkable.bookmarks.build,
                                       quotes: bookmarkable.quotes, leader_spotlights: bookmarkable.leader_spotlights,
                                       workshop_variations: bookmarkable.workshop_variations
    end
  end

  def bookmarkable_class_name
    bookmarkable.object.class.name
  end

  def bookmarks_link
    h.link_to "My Bookmarks", h.bookmarks_path, class: "underline"
  end

  def bookmarkable_link
    if bookmarkable_class_name == "Event"
      bookmarkable.breadcrumb_link
    end
  end

  private

  def header_image
    return unless object.rhino_header.body.present?

    # embeds returns ActiveStorage::Attached::Many; find first image blob
    object.rhino_header.embeds.blobs.find { |blob| blob.image? }
  end
end
