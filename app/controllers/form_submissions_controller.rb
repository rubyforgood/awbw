class FormSubmissionsController < ApplicationController
  before_action :set_form_submission, only: %i[link_organization select_organization create_organization]

  def index
    authorize! FormSubmission

    @person = Person.find_by(id: params[:person_id]) if params[:person_id].present?
    @form = Form.find_by(id: params[:form_id]) if params[:form_id].present?

    if turbo_frame_request?
      @form_submissions = FormSubmission.search_by_params(params)
        .includes(:form, :event, { person: [ :user, { affiliations: :organization } ] }, { form_answers: :form_field })
        .order(created_at: :desc)
        .paginate(page: params[:page], per_page: 50)
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
  # registration one. "Linked" here means the person holds an active affiliation
  # with the submitted organization — there is no submission–org join, so linking
  # creates the affiliations (and unlinking is managed on the person record).
  def link_organization
    authorize! @form_submission, to: :link_organization?
    @person = @form_submission.person
    @entry = submission_org_entry
    @submitted_org_name = @entry[:org_name]
    @submitted_position = @entry[:position]
    @affiliations_by_org = @person.affiliations.includes(:organization).group_by(&:organization_id)
    @creatable_org_names = creatable_org_names
    @potential_matches = if @submitted_org_name.present?
      Organization.remote_search(@submitted_org_name).limit(10)
    else
      Organization.none
    end
    # The already-matching org (if any) gets the linked-card treatment with its
    # unapplied-answer conflicts, like a linked org on the registration editor.
    @matched_organization = matched_organization
    @profile_conflicts = @matched_organization ? profile_diff_for(@matched_organization) : []
  end

  def select_organization
    authorize! @form_submission, to: :select_organization?
    organization = Organization.find(params[:organization_id])

    notice = link_and_report(organization, verb: "linked")

    redirect_to link_organization_form_submission_path(@form_submission, return_to: params[:return_to].presence), notice: notice
  end

  def create_organization
    authorize! @form_submission, to: :create_organization?
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

  # The org whose name matches the submitted answer among the person's active
  # affiliations — the same rule as the index's Linked chip.
  def matched_organization
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

  # Fill the org's blank profile/address fields from the submission (curated
  # values are kept and flagged as discrepancies), create the job + facilitator
  # affiliations, and build the flash notice. Only an agreement-scenario form
  # confers the standing Facilitator affiliation (dated to the submission) —
  # other forms create just the job affiliation.
  def link_and_report(organization, verb:)
    entry = submission_org_entry
    profile_changes = OrganizationServices::SyncProfile.call(
      organization: organization, overwrite: false, website: entry[:website], agency_type: entry[:agency_type]
    ).changes
    address_result = OrganizationServices::UpsertAddress.call(
      organization: organization, overwrite: false, **entry[:address]
    )

    AffiliationServices::CreateFromRegistration.call(
      person: @form_submission.person,
      organization: organization,
      job_title: entry[:position],
      training_date: @form_submission.created_at.to_date,
      organization_address: address_result.address || sole_address(organization),
      facilitator_training: @form_submission.form.purpose?
    )

    stage_conflict_warning(organization)
    saved = profile_changes + address_result.changes
    notice = "#{flash_safe(organization.name)} #{verb}."
    notice += " Saved from the form: #{saved.map { |change| flash_safe(change.description) }.to_sentence}." if saved.any?
    notice
  end

  def stage_conflict_warning(organization)
    conflicts = profile_diff_for(organization)
    return if conflicts.none?

    descriptions = conflicts.map { |conflict| "#{conflict.label} (form: “#{flash_safe(conflict.submitted)}”, saved: “#{flash_safe(conflict.saved)}”)" }
    flash[:warning] = "Some form answers differ from #{flash_safe(organization.name)}’s saved profile and were not applied: #{descriptions.to_sentence}. Edit the organization if they should change."
  end

  def sole_address(organization)
    addresses = organization.addresses.active
    addresses.first if addresses.count == 1
  end

  # Flash messages are rendered with `html_safe`, so anything a respondent typed
  # has to be escaped before it goes into one.
  def flash_safe(text)
    ERB::Util.html_escape(text)
  end
end
