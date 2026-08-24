class FormSubmissionsController < ApplicationController
  before_action :set_form_submission, only: %i[link_organization select_organization create_organization]

  def index
    authorize! FormSubmission

    @person = Person.find_by(id: params[:person_id]) if params[:person_id].present?
    @form = Form.find_by(id: params[:form_id]) if params[:form_id].present?

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
  def linked_orgs_for(submissions)
    ids_by_submission = submissions.to_h { |submission| [ submission.id, submission.linked_organization_ids ] }
    all_ids = ids_by_submission.values.flatten.uniq
    orgs = all_ids.any? ? Organization.where(id: all_ids).index_by(&:id) : {}
    ids_by_submission.transform_values { |ids| ids.filter_map { |id| orgs[id] } }
  end

  # The org-related answers on this submission (canonical or legacy "agency_"
  # identifiers), shaped like a registration submission entry.
  def submission_org_entry
    @submission_org_entry ||= begin
      answers = @form_submission.answers_by_identifier
      read = ->(identifier) do
        FormField.aliased_identifiers(identifier).lazy.filter_map { |name| answers[name].presence }.first
      end
      {
        org_name: read.call("organization_name"),
        position: read.call("organization_position"),
        website: read.call("organization_website"),
        agency_type: read.call("organization_type"),
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

  # The org this submission resolves to: an explicitly linked one first (an
  # admin's resolution, which survives a submitted name that doesn't match the
  # org), else the org whose name matches the submitted answer among the
  # person's active affiliations — the same rule as the index's Linked chip.
  def matched_organization
    explicit = @form_submission.linked_organizations.first
    return explicit if explicit
    return if @submitted_org_name.blank?

    @person.affiliations.select { |a| a.active? && a.organization.name.casecmp?(@submitted_org_name.strip) }
           .map(&:organization).first
  end

  def profile_diff_for(organization)
    entry = submission_org_entry
    OrganizationServices::ProfileDiff.call(
      organization: organization,
      website: entry[:website],
      agency_type: entry[:agency_type],
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
