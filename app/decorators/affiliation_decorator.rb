class AffiliationDecorator < ApplicationDecorator
  def detail(length: nil)
    "#{person.full_name}: #{title.presence || Affiliation::FACILITATOR_TITLE} - #{organization.name}"
  end

  # A blank title means a facilitator affiliation, the same default used elsewhere.
  def display_title
    shown = title.presence || Affiliation::FACILITATOR_TITLE
    shown.strip == Affiliation::FACILITATOR_TITLE ? "AWBW #{Affiliation::FACILITATOR_TITLE}" : shown
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

  # E.g. "Started March 2023, ending next month" — relative wording for months
  # close to now, so an imminent lapse reads at a glance.
  def period_note
    parts = []
    parts << "#{start_date > Date.current ? 'starting' : 'started'} #{relative_month(start_date)}" if start_date
    parts << "#{end_date < Date.current ? 'ended' : 'ending'} #{relative_month(end_date)}" if end_date
    parts.join(", ").upcase_first.presence || "Dates not recorded"
  end

  # Where a back link should land on the person/organization editor. An inactive
  # row sits on the Inactive tab, so jumping to the row itself would scroll to
  # something the page isn't showing — land on the section instead.
  def return_anchor
    active? ? h.dom_id(object) : "affiliations"
  end

  private

  def relative_month(date)
    today = Date.current
    case (date.year * 12 + date.month) - (today.year * 12 + today.month)
    when -1 then "last month"
    when 0 then "this month"
    when 1 then "next month"
    else date.strftime("%B %Y")
    end
  end
end
