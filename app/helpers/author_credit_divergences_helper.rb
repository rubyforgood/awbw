module AuthorCreditDivergencesHelper
  # The 8 AuthorCreditable models label their content differently (title vs name).
  def divergence_record_title(record)
    record.try(:title).presence || record.try(:name).presence || "##{record.id}"
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
