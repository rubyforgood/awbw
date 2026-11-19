class AffiliationDecorator < ApplicationDecorator
  # Shared by the admin affiliations index header and rows so columns line up.
  INDEX_GRID = "grid grid-cols-[180px_180px_130px_132px_132px_110px_64px_190px_150px_110px_64px_40px_88px] gap-x-3".freeze

  # The person-form row palette: role is the hue (FA purple, JA blue), ended rows go light.
  def index_pill_tint
    if facilitator?
      inactive_on? ? :facilitator_light : :facilitator
    else
      inactive_on? ? :nonfac_light : :nonfac
    end
  end

  # Numbered like the org address editor's "Address #N", then the city (or street).
  def index_address_label(address, number)
    place = address.city.presence || address.street_address
    [ number, (address.inactive? ? "#{place} [INACTIVE]" : place) ].compact_blank.join(" · ")
  end

  # Flagged inactive while its dates still read current — the legacy flag disagrees.
  def inactive_flag_disagrees?
    inactive? && !(end_date && end_date < Date.current)
  end

  def index_row_classes
    "#{index_row_bg} #{facilitator? ? "border-purple-200" : "border-blue-200"}"
  end

  def index_row_bg
    facilitator? ? "bg-purple-50" : "bg-blue-50"
  end

  def index_accent_class
    if facilitator?
      inactive_on? ? "bg-purple-300" : "bg-purple-500"
    else
      inactive_on? ? "bg-blue-300" : "bg-blue-500"
    end
  end

  def index_title_classes
    if facilitator?
      inactive_on? ? "bg-purple-50 text-purple-500 border-purple-200" : "bg-purple-100 text-purple-700 font-semibold border-purple-300"
    else
      inactive_on? ? "bg-blue-50 text-blue-500 border-blue-200" : "bg-blue-100 text-blue-700 font-semibold border-blue-300"
    end
  end

  def detail(length: nil)
    "#{[ person.full_name, title ].compact.join(": ")} - #{organization.name}"
  end

  def display_title
    facilitator? ? "AWBW #{Affiliation::FACILITATOR_TITLE}" : title
  end

  def dedupe_label
    [ organization&.name, display_title, period_label ].compact.join(" · ")
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

  # Where a back link should land on the person/organization editor. An inactive
  # row sits on the Inactive tab, so jumping to the row itself would scroll to
  # something the page isn't showing — land on the section instead.
  def return_anchor
    active? ? h.dom_id(object) : "affiliations"
  end
end
