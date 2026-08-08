module AuthorCreditDivergencesHelper
  # The 8 AuthorCreditable models label their content differently (title vs name).
  def divergence_record_title(record)
    record.try(:title).presence || record.try(:name).presence || "##{record.id}"
  end

  # An empty page means "nothing left to reconcile" only when nothing is filtered
  # out — otherwise the congratulations would be reporting on the filter.
  def divergence_filters_applied?
    AuthorCreditDivergencesController::FILTER_KEYS.any? { |key| params[key].present? }
  end

  # New tab rather than an eyebrow: these rows link to 8 different destinations,
  # none of which carries a return_to today.
  def divergence_record_link(record)
    link_to divergence_record_title(record), polymorphic_path(record),
            target: "_blank", rel: "noopener",
            title: "Opens in a new tab",
            class: "text-blue-700 hover:underline"
  end

  # The suggestion is the most restrictive preference across the person's content,
  # but `anonymous` isn't a name format — it's the separate checkbox — so fall back
  # to the profile's current format when that's what was suggested.
  def suggested_display_name_preference(group)
    suggested = group.suggested_preference
    return suggested if Person::DISPLAY_NAME_PREFERENCES.include?(suggested)
    group.person.display_name_preference.presence || "full_name"
  end
end
