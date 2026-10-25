class ProfileChangeRequestsController < ApplicationController
  before_action :set_request, only: [ :edit, :update, :approve, :decline, :resolve ]

  def index
    authorize! ProfileChangeRequest
    @status = ProfileChangeRequest::STATUSES.include?(params[:status]) ? params[:status] : "pending"
    @person = Person.find_by(id: params[:person_id]) if params[:person_id].present?
    # A link to one card (highlight + anchor) loads the queue up front so the card
    # is in the first response for the browser to scroll to.
    load_requests if turbo_frame_request? || params[:highlight].present?
    render :profile_change_requests_results if turbo_frame_request?
  end

  def new
    @person = Person.find(params[:person_id])
    @request = @person.profile_change_requests.new(field: requested_field, requested_by: current_user)
    authorize! @request
    return prepare_affiliation_request if requested_field == "affiliation"
    return prepare_license_request if @request.license?

    existing = @person.profile_change_requests.pending.find_by(field: requested_field)
    return redirect_to edit_profile_change_request_path(existing) if existing

    @request.prefill_current_email
  end

  def create
    @person = Person.find(params[:person_id])
    @request = @person.profile_change_requests.new(profile_change_request_params)
    @request.requested_by = current_user
    authorize! @request

    if @request.save
      notify_admins_and_submitter(@request)
      redirect_to @request.decorate.profile_return_path, status: :see_other,
                  notice: "Thanks — we've sent your change request to AWBW staff."
    else
      @person = @request.person
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @request
    @person = @request.person
  end

  def update
    authorize! @request

    if @request.update(profile_change_request_params)
      redirect_to @request.decorate.profile_return_path, status: :see_other,
                  notice: "Your change request was updated."
    else
      @person = @request.person
      render :edit, status: :unprocessable_content
    end
  end

  def approve
    authorize! @request
    result = Analytics::LifecycleBuffer.tagging(Analytics::LifecycleBuffer::PROFILE_CHANGE_REQUEST_KEY.to_sym => @request.id) do
      ProfileChangeRequests::Apply.call(request: @request, reviewer: current_user, confer_facilitator: params[:confer_facilitator] == "1")
    end

    unless result.applied
      redirect_back_or_to profile_change_requests_path,
                    alert: "Couldn't apply automatically: #{result.message} Use \"Update manually\", then mark it resolved."
      return
    end

    @request.resolve!(method: "approved", reviewer: current_user, note: review_note)
    notify_reviewed(@request)
    respond_with_updated_row("Approved. #{result.message}")
  end

  def resolve
    authorize! @request
    @request.resolve!(method: "manual", reviewer: current_user, note: review_note)
    notify_reviewed(@request)
    respond_with_updated_row("Marked as resolved.")
  end

  def decline
    authorize! @request
    @request.decline!(reviewer: current_user, note: review_note)
    notify_reviewed(@request)
    respond_with_updated_row("Request declined.")
  end

  private

  def load_requests
    scope = authorized_scope(ProfileChangeRequest.all).where(@person ? { person: @person } : {})
    @status_counts = scope.group(:status).count
    @requests = scope.where(status: @status)
                  .includes(:person, :requested_by, :reviewed_by)
                  .newest_first
  end

  def set_request
    @request = ProfileChangeRequest.find(params[:id])
  end

  def requested_field
    ProfileChangeRequest::FIELDS.include?(params[:field]) ? params[:field] : "affiliation"
  end

  def review_note
    params[:reviewer_note].presence
  end

  # One question per page: which organization (skipped when there's only one),
  # then what to change, then a form with just those inputs.
  def prepare_affiliation_request
    @affiliations = @person.affiliations.includes(:organization).select(&:organization)
                           .sort_by { |a| [ a.active? ? 0 : 1, a.organization.name.downcase ] }
    organizations_link = [ new_profile_change_request_path(person_id: @person, field: "affiliation"), "Back to my organizations" ]
    profile_link = [ edit_person_path(@person, anchor: "affiliations"), "Back to editing my profile" ]

    if params[:add].present? || @affiliations.empty?
      @request.requested_value = ProfileChangeRequest::AFFILIATION_CHANGE_ADD
      @back_path, @back_label = @affiliations.any? ? organizations_link : profile_link
      return
    end

    @request.affiliation = params[:affiliation_id].present? ? @affiliations.find { |a| a.id.to_s == params[:affiliation_id].to_s } : (@affiliations.first if @affiliations.one?)
    unless @request.affiliation
      @pending_by_affiliation = @person.profile_change_requests.pending.where(field: "affiliation").index_by(&:affiliation_id)
      @back_path, @back_label = profile_link
      return render :choose_affiliation
    end

    existing = @person.profile_change_requests.pending.find_by(field: "affiliation", affiliation: @request.affiliation)
    return redirect_to edit_profile_change_request_path(existing) if existing

    change = params[:change].presence_in(ProfileChangeRequest::AFFILIATION_CHANGE_TYPES - [ ProfileChangeRequest::AFFILIATION_CHANGE_ADD ])
    unless change
      @back_path, @back_label = @affiliations.many? ? organizations_link : profile_link
      return render :choose_affiliation_change
    end

    @request.requested_value = change
    @back_path = new_profile_change_request_path(person_id: @person, field: "affiliation", affiliation_id: @request.affiliation.id)
    @back_label = "Back"
  end

  def prepare_license_request
    @request.professional_license = @person.professional_licenses.find(params[:professional_license_id])
    existing = @person.profile_change_requests.pending.find_by(field: @request.field, professional_license: @request.professional_license)
    redirect_to edit_profile_change_request_path(existing) if existing
  end

  def profile_change_request_params
    params.require(:profile_change_request).permit(
      :field, :requested_value, :details, :affiliation_id, :organization_id, :professional_license_id, :proposed_email_type,
      :proposed_title, :proposed_start_date, :proposed_end_date, :proposed_organization_name, :proposed_organization_address_id,
      :proposed_street_address, :proposed_city, :proposed_state, :proposed_state_outside_usa, :proposed_zip_code, :leaving_job, left_organization_ids: []
    )
  end

  def respond_with_updated_row(notice)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render "profile_change_requests/update_request"
      end
      format.html { redirect_back_or_to profile_change_requests_path, notice: notice }
    end
  end

  def notify_admins_and_submitter(request)
    NotificationServices::CreateNotification.call(
      noticeable: request,
      recipient_role: :admin,
      recipient_email: Setting.programs_email,
      kind: "profile_change_requested_fyi",
      notification_type: "profile_change_requested_notification",
      sender: current_user
    )
    NotificationServices::CreateNotification.call(
      noticeable: request,
      recipient_role: :person,
      recipient_email: current_user.email,
      kind: "profile_change_requested",
      notification_type: "profile_change_requested_confirmation",
      sender: current_user
    )
  end

  def notify_reviewed(request)
    email = request.requested_by&.email
    return if email.blank?

    NotificationServices::CreateNotification.call(
      noticeable: request,
      recipient_role: :person,
      recipient_email: email,
      kind: "profile_change_reviewed",
      notification_type: "profile_change_reviewed_notification",
      sender: current_user
    )
  end
end
