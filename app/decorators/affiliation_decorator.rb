class AffiliationDecorator < ApplicationDecorator
  def detail(length: nil)
    "#{person.full_name}: #{title.presence || Affiliation::FACILITATOR_TITLE} - #{organization.name}"
  end

  def status_badge
    classes, icon = case status_on
    when "Active" then [ "bg-green-50 text-green-800 border-green-300", "fa-solid fa-circle-check" ]
    when "Upcoming" then [ "bg-amber-50 text-amber-800 border-amber-300", "fa-solid fa-clock" ]
    else [ "bg-gray-100 text-gray-600 border-gray-300", "fa-solid fa-circle-minus" ]
    end
    h.render "shared/badge", label: status_on, classes: classes, icon: icon
  end

  def period_label
    start_text = start_date&.strftime("%b %Y")
    finish_text = end_date&.strftime("%b %Y")
    return "#{start_text} – #{finish_text}" if start_text && finish_text
    return "Ended #{finish_text}" if finish_text
    if start_text
      return "Starts #{start_text}" if start_date > Date.current
      return "Since #{start_text}"
    end
    "Dates not recorded"
  end

  # Compact "started – ended" range for the affiliation, e.g. "Sep 17, 2026 – present".
  # Reads "no start date" when unset so a blank date isn't silently omitted.
  def date_range
    start = start_date ? h.l(start_date, format: :long) : "no start date"
    finish = end_date ? h.l(end_date, format: :long) : "present"
    "#{start} – #{finish}"
  end
end
