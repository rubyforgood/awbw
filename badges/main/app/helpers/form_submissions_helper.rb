module FormSubmissionsHelper
  # The index filters that a submission's detail page must hand back so the trip
  # to View a submission and back lands on the same filtered list. `person_id` and
  # `form_id` are threaded separately (the View link scopes person_id to the row),
  # so only the newer filters live here. Blank values are dropped.
  def form_submission_carryover_params(params)
    {
      event_id: params[:event_id].presence,
      organization_id: params[:organization_id].presence,
      role: params[:role].presence,
      search: params[:search].presence,
      org_status: params[:org_status].presence,
      account_status: params[:account_status].presence,
      scenario: params[:scenario].presence,
      start_date: params[:start_date].presence,
      end_date: params[:end_date].presence
    }.compact
  end

  # True when any index filter is active — drives whether "Clear filters" shows.
  def form_submission_filters_active?(params)
    params.values_at(:person_id, :form_id, :event_id, :organization_id, :role,
                     :search, :org_status, :account_status, :scenario,
                     :start_date, :end_date).any?(&:present?)
  end
end
