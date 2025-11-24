class EventDecorator < Draper::Decorator
  delegate_all
  decorates_association :bookmarkable

  def date
    start_date.strftime("%B %d, %Y")
  end

  def calendar_links
    start_time   = object.start_date.strftime("%Y%m%dT%H%M%SZ")
    end_time     = object.end_date.strftime("%Y%m%dT%H%M%SZ")
    title_encoded = ERB::Util.url_encode(object.title)
    desc_encoded  = ERB::Util.url_encode(object.description.to_s)

    google_link =
      "https://calendar.google.com/calendar/render?action=TEMPLATE" \
        "&text=#{title_encoded}&dates=#{start_time}/#{end_time}&details=#{desc_encoded}"

    apple_link =
      "data:text/calendar;charset=utf8,BEGIN:VCALENDAR\n" \
        "VERSION:2.0\n" \
        "BEGIN:VEVENT\n" \
        "SUMMARY:#{object.title}\n" \
        "DTSTART:#{start_time}\n" \
        "DTEND:#{end_time}\n" \
        "DESCRIPTION:#{object.description}\n" \
        "END:VEVENT\n" \
        "END:VCALENDAR"

    outlook_link =
      "https://outlook.live.com/owa/?rru=addevent" \
        "&startdt=#{start_time}&enddt=#{end_time}" \
        "&subject=#{title_encoded}&body=#{desc_encoded}"

    office365_link =
      "https://outlook.office.com/owa/?rru=addevent" \
        "&startdt=#{start_time}&enddt=#{end_time}" \
        "&subject=#{title_encoded}&body=#{desc_encoded}"

    yahoo_link =
      "https://calendar.yahoo.com/?v=60" \
        "&title=#{title_encoded}&st=#{start_time}" \
        "&et=#{end_time}&desc=#{desc_encoded}"

    h.safe_join(
      [
        h.link_to("Google", google_link, class: "text-blue-600 hover:underline text-xs"),
        h.content_tag(:span, "•", class: "text-gray-300"),
        h.link_to("Apple", apple_link, class: "text-blue-600 hover:underline text-xs", download: "#{object.title.parameterize}.ics"),
        h.content_tag(:span, "•", class: "text-gray-300"),
        h.link_to("Outlook", outlook_link, class: "text-blue-600 hover:underline text-xs"),
        h.content_tag(:span, "•", class: "text-gray-300"),
        h.link_to("Office 365", office365_link, class: "text-blue-600 hover:underline text-xs"),
        h.content_tag(:span, "•", class: "text-gray-300"),
        h.link_to("Yahoo", yahoo_link, class: "text-blue-600 hover:underline text-xs")
      ],
      " "
    )
  end

  def times(display_day: false, display_date: false)
    s = start_date
    e = end_date || start_date

    # helpers
    day  = ->(d) { d.strftime("%a") }
    date = ->(d) { d.strftime("%b %-d") }

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

    # --------------------------------------------------
    # DIFFERENT DAY → two lines
    # --------------------------------------------------
    if s.to_date != e.to_date
      line1 = "Start: "
      line1 << "#{day.call(s)}, " if display_day
      line1 << "#{date.call(s)} @ " if display_date
      line1 << format_time.call(s)

      line2 = "End: "
      line2 << "#{day.call(e)}, " if display_day
      line2 << "#{date.call(e)} @ " if display_date
      line2 << format_time.call(e)

      return "#{line1}<br>#{line2}"
    end

    # --------------------------------------------------
    # SAME DAY → one line unless times differ
    # --------------------------------------------------
    same_exact_time = (s.hour == e.hour) && (s.min == e.min)

    line = ""
    line << "#{day.call(s)}, " if display_day
    line << "#{date.call(s)} @ " if display_date

    if same_exact_time
      # Only one time
      line << format_time.call(s)
    else
      # Start time
      s_hour = s.strftime("%-l")
      s_min  = s.strftime("%M")
      s_ampm = s.strftime("%P")

      e_hour = e.strftime("%-l")
      e_min  = e.strftime("%M")
      e_ampm = e.strftime("%P")

      hide_start_min = (s_min == "00")
      hide_end_min   = (e_min == "00")
      hide_start_ampm = (s_ampm == e_ampm)

      # Start
      line << s_hour
      line << ":#{s_min}" unless hide_start_min
      line << " #{s_ampm}" unless hide_start_ampm

      line << " - "

      # End
      line << e_hour
      line << ":#{e_min}" unless hide_end_min
      line << " #{e_ampm}"
    end

    line
  end

  def breadcrumbs
    "#{bookmarks_link} >> #{bookmarkable_link}".html_safe
  end

  def content
    if bookmarkable_class_name == 'Workshop'
      h.render '/workshops/show', workshop: bookmarkable, sectors: bookmarkable.sectors,
                                       new_bookmark: bookmarkable.bookmarks.build,
                                       quotes: bookmarkable.quotes, leader_spotlights: bookmarkable.leader_spotlights,
                                       workshop_variations: bookmarkable.workshop_variations
    end
  end

  def bookmarkable_class_name
    bookmarkable.object.class.name
  end

  def bookmarks_link
    h.link_to 'My Bookmarks',h.bookmarks_path, class: 'underline'
  end

  def bookmarkable_link
    if bookmarkable_class_name == 'Event'
      bookmarkable.breadcrumb_link
    end
  end
end
