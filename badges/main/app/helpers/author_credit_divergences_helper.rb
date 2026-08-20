module AuthorCreditDivergencesHelper
  # The models label their content differently (title vs name).
  def divergence_record_title(record)
    record.try(:title).presence || record.try(:name).presence || "##{record.id}"
  end

  # Sections 3 and 4 have no name to guess from, so any suggestion is passed in.
  def assignable_rows(records, suggested_author: nil)
    records.map do |record|
      AuthorCreditDivergenceQuery::AssignableRow.new(record: record, suggested_author: suggested_author)
    end
  end

  # Otherwise the congratulations would be reporting on the filter.
  def divergence_filters_applied?
    AuthorCreditDivergencesController::FILTER_KEYS.any? { |key| params[key].present? }
  end

  # New tab rather than an eyebrow: 8 destinations, none carrying a return_to today.
  def divergence_record_link(record)
    link_to divergence_record_title(record), edit_polymorphic_path(record),
            target: "_blank", rel: "noopener",
            title: "Opens in a new tab",
            class: "text-blue-700 hover:underline"
  end

  # `anonymous` isn't a name format — it's the separate checkbox — so fall back.
  def suggested_display_name_preference(group)
    suggested = group.suggested_preference
    return suggested if Person::DISPLAY_NAME_PREFERENCES.include?(suggested)
    group.person.display_name_preference.presence || "full_name"
  end
end
