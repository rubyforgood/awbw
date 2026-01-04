class WorkshopLogDecorator < ApplicationDecorator
  def detail(length: nil)
    description = length ? description&.truncate(length) : description
    "#{description}<br>#{participants_table}".html_safe
  end

  PARTICIPANT_FIELDS = {
    children: %i[children_first_time children_ongoing],
    teens:    %i[teens_first_time teens_ongoing],
    adults:   %i[adults_first_time adults_ongoing]
  }.freeze

  #
  # Totals by age group
  #
  def children_total
    sum_fields(:children)
  end

  def teens_total
    sum_fields(:teens)
  end

  def adults_total
    sum_fields(:adults)
  end

  #
  # Totals by participation type
  #
  def first_time_total
    children_first_time.to_i +
      teens_first_time.to_i +
      adults_first_time.to_i
  end

  def ongoing_total
    children_ongoing.to_i +
      teens_ongoing.to_i +
      adults_ongoing.to_i
  end

  #
  # Grand total
  #
  def participants_total
    first_time_total + ongoing_total
  end

  #
  # Structured totals (useful for tables / JSON / charts)
  #
  def participant_totals
    {
      children: {
        first_time: children_first_time.to_i,
        ongoing: children_ongoing.to_i,
        total: children_total
      },
      teens: {
        first_time: teens_first_time.to_i,
        ongoing: teens_ongoing.to_i,
        total: teens_total
      },
      adults: {
        first_time: adults_first_time.to_i,
        ongoing: adults_ongoing.to_i,
        total: adults_total
      },
      totals: {
        first_time: first_time_total,
        ongoing: ongoing_total,
        overall: participants_total
      }
    }
  end

  private

  def header
    h.content_tag(:thead) do
      h.content_tag(:tr) do
        %w[Group First\ Time Ongoing Total].map do |label|
          h.content_tag(
            :th,
            label,
            style: "border:1px solid #ddd; padding:6px; text-align:left; background:#f9f9f9;"
          )
        end.join.html_safe
      end
    end
  end

  def body(totals)
    h.content_tag(:tbody) do
      %i[children teens adults].map do |group|
        row(
          group.to_s.titleize,
          totals[group][:first_time],
          totals[group][:ongoing],
          totals[group][:total]
        )
      end.join.html_safe
    end
  end

  def footer(totals)
    h.content_tag(:tfoot) do
      row(
        "Total",
        totals[:totals][:first_time],
        totals[:totals][:ongoing],
        totals[:totals][:overall],
        strong: true
      )
    end
  end

  def row(label, first_time, ongoing, total, strong: false)
    cells = [
      label,
      first_time,
      ongoing,
      total
    ].map do |value|
      h.content_tag(
        :td,
        strong ? h.content_tag(:strong, value) : value,
        style: "border:1px solid #ddd; padding:6px;"
      )
    end

    h.content_tag(:tr) { cells.join.html_safe }
  end

  def participants_table
    totals = participant_totals

    <<~HTML.html_safe
    <table width="100%" cellpadding="0" cellspacing="0"
           role="presentation"
           style="border-collapse:collapse; margin-top:12px;">
      #{participants_table_header}
      #{participants_table_row("Children", totals[:children])}
      #{participants_table_row("Teens", totals[:teens])}
      #{participants_table_row("Adults", totals[:adults])}
      #{participants_table_total_row(totals[:totals])}
    </table>
  HTML
  end

  private

  def cell_style(extra = "")
    [
      "border:1px solid #ddd",
      "padding:6px",
      "display:table-cell",
      "vertical-align:top",
      extra
    ].join("; ")
  end

  def participants_table_header
    <<~HTML
    <tr>
      <td style="#{cell_style("font-weight:bold;background:#f5f5f5")}">Group</td>
      <td style="#{cell_style("font-weight:bold;background:#f5f5f5")}">First Time</td>
      <td style="#{cell_style("font-weight:bold;background:#f5f5f5")}">Ongoing</td>
      <td style="#{cell_style("font-weight:bold;background:#f5f5f5")}">Total</td>
    </tr>
  HTML
  end

  def participants_table_row(label, data)
    <<~HTML
    <tr>
      <td style="#{cell_style}">#{label}</td>
      <td style="#{cell_style}">#{data[:first_time]}</td>
      <td style="#{cell_style}">#{data[:ongoing]}</td>
      <td style="#{cell_style}">#{data[:total]}</td>
    </tr>
  HTML
  end

  def participants_table_total_row(totals)
    <<~HTML
    <tr>
      <td style="#{cell_style("font-weight:bold")}">Total</td>
      <td style="#{cell_style("font-weight:bold")}">#{totals[:first_time]}</td>
      <td style="#{cell_style("font-weight:bold")}">#{totals[:ongoing]}</td>
      <td style="#{cell_style("font-weight:bold")}">#{totals[:overall]}</td>
    </tr>
  HTML
  end

  def sum_fields(group)
    PARTICIPANT_FIELDS[group].sum { |field| object.public_send(field).to_i }
  end
end
