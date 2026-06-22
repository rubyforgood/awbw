class EventDecorator < ApplicationDecorator
  decorates_association :bookmarkable

  def videoconference_domain
    URI.parse(videoconference_url).host&.split(".")&.[](-2)&.capitalize rescue "video call"
  end

  # The meeting room pulled out of the join URL so registrants can dial in
  # manually: the numeric ID for Zoom (".../j/1234567890") or the meeting code
  # for Google Meet ("meet.google.com/abc-defg-hij"). Returns a { label:, value: }
  # hash, or nil when the URL is blank or the platform isn't recognized.
  def videoconference_room
    return if videoconference_url.blank?

    uri = URI.parse(videoconference_url)
    host = uri.host.to_s.downcase

    if host.end_with?("zoom.us")
      id = uri.path[%r{/(?:j|wc/join|wc)/(\d+)}, 1]
      id && { label: "Meeting ID", value: format_zoom_meeting_id(id) }
    elsif host == "meet.google.com"
      code = uri.path.delete_prefix("/").presence
      code && { label: "Meeting code", value: code }
    end
  rescue URI::InvalidURIError
    nil
  end

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

  # Weekday-prefixed date range (e.g. "Thu-Fri, Jan 1-2, 2026") that collapses the
  # year — and the month/weekday where possible — so nothing repeats unnecessarily.
  def date_range
    s = start_date.in_time_zone(Time.zone)
    e = (end_date || start_date).in_time_zone(Time.zone)
    return s.strftime("%a, %b %-d, %Y") if s.to_date == e.to_date

    if s.year == e.year && s.month == e.month
      "#{s.strftime('%a')}-#{e.strftime('%a')}, #{s.strftime('%b')} #{s.strftime('%-d')}-#{e.strftime('%-d')}, #{s.strftime('%Y')}"
    elsif s.year == e.year
      "#{s.strftime('%a, %b %-d')} - #{e.strftime('%a, %b %-d')}, #{s.strftime('%Y')}"
    else
      "#{s.strftime('%a, %b %-d, %Y')} - #{e.strftime('%a, %b %-d, %Y')}"
    end
  end

  def detail(length: nil)
    length ? description&.truncate(length) : description
  end

  # `show_videoconference_details` controls whether the join link/ID/passcode are
  # carried into the calendar entry. Callers with a registration pass that
  # registrant's gate (date + paid/intends); the default falls back to the
  # event-level date gate for registration-less contexts.
  def calendar_links(show_videoconference_details: object.videoconference_details_visible?)
    start_time   = object.start_date.utc.strftime("%Y%m%dT%H%M%SZ")
    end_time     = object.end_date.utc.strftime("%Y%m%dT%H%M%SZ")
    title_encoded = ERB::Util.url_encode(object.title)

    # The join URL doubles as the calendar location, so withhold it from there
    # too until the details may be shared — a physical location (if any) takes
    # its place, otherwise the entry is left without a location.
    has_url      = object.videoconference_url.present? && show_videoconference_details
    has_location = object.location.present?
    location_name = has_location ? object.location.name : nil

    # If both: URL in location field, physical location in description
    # If only URL: URL in location field
    # If only location: location in location field
    # Prefer the admin-authored, calendar-specific blurb; fall back to a
    # flattened version of the rich show-page description when it's blank.
    event_description = object.calendar_description.presence || object.rhino_description.to_plain_text

    if has_url && has_location
      cal_location = object.videoconference_url
      base_description = "#{location_name}\n\n#{event_description}"
    elsif has_url
      cal_location = object.videoconference_url
      base_description = event_description
    elsif has_location
      cal_location = location_name
      base_description = event_description
    else
      cal_location = nil
      base_description = event_description
    end

    # Carry the join link, meeting ID/code, and passcode into the calendar entry
    # so registrants have everything they need to connect straight from the event
    # — but only once the details may be shared (date + paid/intends).
    vc_details = videoconference_calendar_details if show_videoconference_details
    description = [ vc_details, base_description ].compact_blank.join("\n\n")

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

  # True when the event spans more than one calendar day in the viewer's time
  # zone. Display-derived (so it agrees with the dates actually shown), which is
  # why it lives here rather than on the model. Drives singular/plural labels and
  # the "both days" notes in the registration details panel.
  def multi_day?
    return false unless start_date && end_date
    start_date.in_time_zone(Time.zone).to_date != end_date.in_time_zone(Time.zone).to_date
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
    # DIFFERENT DAY → date range + per-day time range
    # The event runs the same hours each day, so we show the date span and a
    # single start-end time (e.g. "Mon-Wed, Apr 21-23 @ 9 am - 4:30 pm PST")
    # rather than a continuous range that would imply an overnight event.
    # --------------------------------------------------
    if s.to_date != e.to_date
      date_part = if s.month == e.month && s.year == e.year
        "#{date.call(s)}-#{e.strftime('%-d')}"
      elsif s.year == e.year
        "#{date.call(s)} - #{date.call(e)}"
      else
        "#{s.strftime('%b %-d, %Y')} - #{e.strftime('%b %-d, %Y')}"
      end

      parts = []
      parts << "#{day.call(s)}-#{day.call(e)}, " if display_day
      parts << "#{date_part} @ " if display_date
      parts << "#{format_time.call(s)} - #{format_time.call(e)}"
      parts << tz_display
      return h.safe_join(parts)
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
    return if cost_cents.blank?
    return "Free event" if cost_cents.zero?

    "Cost: #{MoneyFormatter.dollars_from_cents(cost_cents)}"
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

  # The videoconference connection block (join link, meeting ID/code, passcode)
  # as plain text for embedding in calendar entries. Nil when there's no link.
  # Whether it's actually embedded is the caller's call (see #calendar_links).
  def videoconference_calendar_details
    return if videoconference_url.blank?

    lines = [ "Join on #{videoconference_domain}: #{videoconference_url}" ]
    if (room = videoconference_room)
      lines << "#{room[:label]}: #{room[:value]}"
    end
    lines << "Passcode: #{videoconference_passcode}" if videoconference_passcode.present?
    lines.join("\n")
  end

  # Group Zoom meeting-ID digits the way Zoom's own UI does so they're easy to
  # read aloud/type (e.g. "88285411273" → "882 8541 1273"). Unknown lengths are
  # returned unchanged.
  def format_zoom_meeting_id(id)
    case id.length
    when 11 then id.sub(/\A(\d{3})(\d{4})(\d{4})\z/, '\1 \2 \3')
    when 10 then id.sub(/\A(\d{3})(\d{3})(\d{4})\z/, '\1 \2 \3')
    else id
    end
  end

  def header_image
    return unless object.rhino_header.body.present?

    # embeds returns ActiveStorage::Attached::Many; find first image blob
    object.rhino_header.embeds.blobs.find { |blob| blob.image? }
  end
end
