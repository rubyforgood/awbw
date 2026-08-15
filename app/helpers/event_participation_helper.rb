module EventParticipationHelper
  # Anchor on both organization pages' "Program status" block, so returning from
  # the participation report lands on the chips the user clicked.
  PROGRAM_STATUS_ANCHOR = "program-status".freeze

  # Eyebrow back-link for the participation report as [label, path]. The report is
  # reachable from the reports hub, an event dashboard, and the program-status
  # chips on an organization's profile or edit form; each origin passes return_to
  # (plus the id the path needs) so the user goes back where they came from.
  def participation_return_link
    organization_id = params[:organization_id]

    case params[:return_to]
    when "organization"
      return [ "← Organization", organization_path(organization_id, anchor: PROGRAM_STATUS_ANCHOR) ] if organization_id.present?
    when "organization_edit"
      return [ "← Organization", edit_organization_path(organization_id, anchor: PROGRAM_STATUS_ANCHOR) ] if organization_id.present?
    when "dashboard"
      return [ "← Dashboard", dashboard_event_path(params[:event_id]) ] if params[:event_id].present?
    end

    [ "← Reports", reports_events_path(report_to_hub_params) ]
  end

  # A small, neutral year-over-year change indicator for a headcount, e.g.
  # "▲ 12" / "▼ 3". Direction only, uncoloured. Returns nil when there's no prior
  # period or no change.
  def participation_delta(current_count, prior_count)
    return nil if prior_count.nil?
    delta = current_count - prior_count
    return nil if delta.zero?
    arrow = delta.positive? ? "▲" : "▼"
    content_tag(:span, "#{arrow} #{number_with_delimiter(delta.abs)}",
                class: "text-xs text-gray-400 tabular-nums")
  end
end
