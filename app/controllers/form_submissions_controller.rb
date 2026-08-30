class FormSubmissionsController < ApplicationController
  before_action :set_form_submission, only: %i[link_organization select_organization create_organization]

  def index
    authorize! FormSubmission

    @person = Person.find_by(id: params[:person_id]) if params[:person_id].present?
    # The eyebrow/heading only names a single form; when several are selected the
    # results say "across N forms" instead, so @form stays nil.
    @form_ids = Array(params[:form_id]).reject(&:blank?)
    @form = Form.find_by(id: @form_ids.first) if @form_ids.one?

    if turbo_frame_request?
      @form_submissions = FormSubmission.search_by_params(params)
        .includes(:form, :event, { person: :user }, { form_answers: :form_field })
        .order(created_at: :desc)
        .paginate(page: params[:page], per_page: 50)
      @linked_orgs = linked_orgs_for(@form_submissions)
      render :form_submissions_results
    else
      @forms = Form.order(:name)
      @roles = FormSubmission.distinct.pluck(:role).compact.sort
      render :index
    end
  end

  def show
    @form_submission = FormSubmission.find(params[:id])
    authorize! @form_submission
  end

  # Admin-only audit of everything this submission's smart-field answers changed
  # across records, read back from the stamped Ahoy lifecycle events.
  def changes
    @form_submission = FormSubmission.find(params[:id])
    authorize! @form_submission, to: :changes?
    changes = FormSubmissionChanges.new(@form_submission)
    @change_groups = changes.edited_groups
    @changed_count = changes.edited_count
  end

  # Org-linking editor for a standalone submission, mirroring the event
  # registration one. "Linked" here means an org was explicitly linked to this
  # submission (metadata) or the person holds an active affiliation matching the
  # submitted name; linking creates the affiliations (unlinking is managed on
  # the person record).
  def link_organization
    authorize! @form_submission
    @person = @form_submission.person
    @entry = submission_org_entry
    @submitted_org_name = @entry[:org_name]
    @submitted_position = @entry[:position]
    @affiliations_by_org = @person.affiliations.includes(:organization).group_by(&:organization_id)
    @creatable_org_names = creatable_org_names
    # The already-matching org (if any) gets the linked-card treatment with its
    # unapplied-answer conflicts, like a linked org on the registration editor.
    @matched_organization = matched_organization
    @profile_conflicts = @matched_organization ? profile_diff_for(@matched_organization) : []
    # The org already shown as linked is left out of the suggestions, so the page
    # can't offer to link what it just linked (as on the registration editor).
    @potential_matches = if @submitted_org_name.present?
      Organization.remote_search(@submitted_org_name).where.not(id: @matched_organization&.id).limit(10)
    else
      Organization.none
    end
  end

  def select_organization
    authorize! @form_submission
    organization = Organization.find_by(id: params[:organization_id])
    if organization.nil?
      redirect_to link_organization_form_submission_path(@form_submission, return_to: params[:return_to].presence), alert: "Choose an organization to link."
      return
    end

    notice = link_and_report(organization, verb: "linked")

    redirect_to link_organization_form_submission_path(@form_submission, return_to: params[:return_to].presence), notice: notice
  end

  def create_organization
    authorize! @form_submission
    # Build the org from the name actually submitted on the form, so the button
    # can't create an arbitrary org — it only resolves the submitted name.
    name = submission_org_entry[:org_name].presence&.strip
    if name.blank?
      redirect_to link_organization_form_submission_path(@form_submission, return_to: params[:return_to].presence), alert: "No submitted organization name to create from."
      return
    end

    existing = Organization.where("LOWER(name) = ?", name.downcase).first
    organization = existing || Organization.create!(name: name, organization_status: OrganizationStatus.find_by(name: "Active"))

    notice = link_and_report(organization, verb: existing ? "linked" : "created and linked")

    redirect_to link_organization_form_submission_path(@form_submission, return_to: params[:return_to].presence), notice: notice
  end

  private

  def set_form_submission
    @form_submission = FormSubmission.includes(:form, person: { affiliations: :organization }).find(params[:id])
  end

  # {submission_id => [Organization]} for the directly-linked orgs across the page,
  # in one query, so the index can show the linked org chips without an N+1 over
  # each submission's metadata id list.
  # Both direct links per submission (ADR-0002 D5): the metadata ids, plus the
  # registration-org rows pinned to these submissions — one query for the page.
  def linked_orgs_for(submissions)
    ids_by_submission = submissions.to_h { |submission| [ submission.id, submission.linked_organization_ids ] }
    EventRegistrationOrganization.where(form_submission_id: ids_by_submission.keys)
      .pluck(:form_submission_id, :organization_id)
      .each { |submission_id, organization_id| ids_by_submission[submission_id] |= [ organization_id ] }
    all_ids = ids_by_submission.values.flatten.uniq
    orgs = all_ids.any? ? Organization.where(id: all_ids).index_by(&:id) : {}
    ids_by_submission.transform_values { |ids| ids.filter_map { |id| orgs[id] } }
  end

  # The org-related answers on this submission, shaped like a registration
  # submission entry.
  def submission_org_entry
    @submission_org_entry ||= begin
      answers = @form_submission.answers_by_identifier
      read = ->(identifier) { answers[identifier].presence }
      {
        org_name: read.call("organization_name"),
        position: read.call("organization_position"),
        website: read.call("organization_website"),
        organization_type: read.call("organization_type"),
        address: {
          street_address: read.call("organization_street"),
          city: read.call("organization_city"),
          state: read.call("organization_state"),
          zip_code: read.call("organization_zip"),
          country: read.call("organization_country")
        }
      }
    end
  end

  def creatable_org_names
    name = @submitted_org_name.presence&.strip
    return [] if name.blank?
    Organization.where("LOWER(name) = ?", name.downcase).exists? ? [] : [ name ]
  end

  # The org this submission resolves to, by direct link only — an affiliation the
  # person happens to hold under the submitted name is not a link. Two links
  # carry it: the explicit one an admin recorded on the submission (which
  # survives a submitted name that doesn't match the org it resolved to), and
  # the registration-org row this submission is pinned to (public registration
  # pins the submission as it creates the link).
  def matched_organization
    @form_submission.linked_organizations.first || registration_linked_organization
  end

  # The org on the registration-org link pinned to this submission. Rows created
  # before that pin existed fall back to the registration's sole linked org — the
  # same single-org rule the registration editor pairs submitted answers by.
  def registration_linked_organization
    return if @form_submission.person_id.blank?

    pinned = EventRegistrationOrganization.find_by(form_submission_id: @form_submission.id)
    return pinned.organization if pinned
    return if @form_submission.event_id.blank?

    links = EventRegistrationOrganization.joins(:event_registration).where(
      event_registrations: { event_id: @form_submission.event_id, registrant_id: @form_submission.person_id }
    )
    links.sole.organization if links.count == 1
  end

  def profile_diff_for(organization)
    entry = submission_org_entry
    OrganizationServices::ProfileDiff.call(
      organization: organization,
      website: entry[:website],
      organization_type: entry[:organization_type],
      address: entry[:address]
    )
  end

  # Fill the org's blank profile/address fields from the submission, create the
  # affiliations, record the explicit submission -> org link, and build the flash
  # notice — via the linking core shared with the event registration editor.
  # The scenario (derived from the form's role) drives the affiliation
  # handling: agreement scenarios confer the standing Facilitator affiliation
  # dated to the submission, and a new job ends the person's other orgs' rows.
  def link_and_report(organization, verb:)
    result = OrganizationServices::LinkSubmittedOrganization.call(
      person: @form_submission.person,
      organization: organization,
      entry: submission_org_entry,
      scenario: @form_submission.linking_scenario,
      training_date: @form_submission.created_at.to_date
    )

    # The explicit link keeps this submission reading as linked even when the
    # submitted name differs from the org it was resolved to; the ended ids let
    # the processing panel flag what the scenario end-dated, for correction.
    @form_submission.link_organization!(organization.id)
    @form_submission.record_scenario_ended!(result.ended_affiliations.map(&:id))

    warning = result.warning(organization: organization)
    flash[:warning] = warning if warning
    result.notice(organization: organization, verb: verb)
  end
end
