class WorkshopLogDecorator < ApplicationDecorator
  def detail(length: nil)
    description = length ? object.description&.truncate(length) : object.description
    "#{description}<br>#{participants_table}".html_safe
  end

  private

  def participants_table
    children_first = object.children_first_time.to_i
    children_ongoing = object.children_ongoing.to_i

    teens_first = object.teens_first_time.to_i
    teens_ongoing = object.teens_ongoing.to_i

    adults_first = object.adults_first_time.to_i
    adults_ongoing = object.adults_ongoing.to_i

    totals_first = children_first + teens_first + adults_first
    totals_ongoing = children_ongoing + teens_ongoing + adults_ongoing

    <<~HTML.html_safe
      <table width="100%" cellpadding="0" cellspacing="0"
             style="border-collapse:collapse; margin-top:12px;">
        #{header_row}
        #{data_row("Children", children_first, children_ongoing)}
        #{data_row("Teens", teens_first, teens_ongoing)}
        #{data_row("Adults", adults_first, adults_ongoing)}
        #{total_row(totals_first, totals_ongoing)}
      </table>
    HTML
  end

  def header_row
    %w[Group First\ Time Ongoing Total].map do |label|
      "<td style=\"#{cell_style('font-weight:bold;background:#f5f5f5')}\">#{label}</td>"
    end.then { |cells| "<tr>#{cells.join}</tr>" }
  end

  def data_row(label, first, ongoing)
    total = first + ongoing

    "<tr>" \
      "<td style=\"#{cell_style}\">#{label}</td>" \
      "<td style=\"#{cell_style}\">#{first}</td>" \
      "<td style=\"#{cell_style}\">#{ongoing}</td>" \
      "<td style=\"#{cell_style}\">#{total}</td>" \
      "</tr>"
  end

  def total_row(first, ongoing)
    total = first + ongoing

    "<tr>" \
      "<td style=\"#{cell_style('font-weight:bold')}\">Total</td>" \
      "<td style=\"#{cell_style('font-weight:bold')}\">#{first}</td>" \
      "<td style=\"#{cell_style('font-weight:bold')}\">#{ongoing}</td>" \
      "<td style=\"#{cell_style('font-weight:bold')}\">#{total}</td>" \
      "</tr>"
  end

  def cell_style(extra = "")
    [
      "border:1px solid #ddd",
      "padding:6px",
      "display:table-cell",
      "vertical-align:top",
      extra
    ].reject(&:blank?).join("; ")
  end
end
