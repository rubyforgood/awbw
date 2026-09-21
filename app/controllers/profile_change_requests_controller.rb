class ProfileChangeRequestsController < ApplicationController
  before_action :set_request, only: [ :edit, :update, :approve, :decline, :resolve ]

  def index
    authorize! ProfileChangeRequest, to: :index?
    @status = ProfileChangeRequest::STATUSES.include?(params[:status]) ? params[:status] : "pending"
    return unless turbo_frame_request?

    @requests = authorized_scope(ProfileChangeRequest.all)
                  .where(status: @status)
                  .includes(:person, :requested_by, :reviewed_by)
                  .newest_first
    render :profile_change_requests_results
  end

  def new
    @person = Person.find(params[:person_id])
    @request = @person.profile_change_requests.new(field: requested_field, requested_by: current_user)
    authorize! @request, to: :new?

    # Affiliation requests target a specific affiliation chosen on the form, so we
    # can't resolve "the" existing one here — only the single-target fields dedupe.
    return if requested_field == "affiliation"

    existing = @person.profile_change_requests.pending.find_by(field: requested_field)
    redirect_to edit_profile_change_request_path(existing) if existing
  end

  def create
    @person = Person.find(params[:person_id])
    @request = @person.profile_change_requests.new(profile_change_request_params)
    @request.requested_by = current_user
    authorize! @request, to: :create?

    if @request.save
      notify_admins_and_submitter(@request)
      redirect_to edit_person_path(@person, anchor: "affiliations"), status: :see_other,
                  notice: "Thanks — we've sent your change request to AWBW staff."
    else
      @person = @request.person
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @request, to: :update?
    @person = @request.person
  end

  def update
    authorize! @request, to: :update?

    if @request.update(profile_change_request_params)
      redirect_to edit_person_path(@request.person, anchor: "affiliations"), status: :see_other,
                  notice: "Your change request was updated."
    else
      @person = @request.person
      render :edit, status: :unprocessable_content
    end
  end

  def approve
    authorize! @request, to: :approve?
    result = ProfileChangeRequests::Apply.call(request: @request, reviewer: current_user)

    unless result.applied
      redirect_back fallback_location: profile_change_requests_path,
                    alert: "Couldn't apply automatically: #{result.message} Use \"Update manually\", then mark it resolved."
      return
    end

    @request.resolve!(method: "approved", reviewer: current_user)
    notify_reviewed(@request)
    respond_with_updated_row("Approved. #{result.message}")
  end

  def resolve
    authorize! @request, to: :resolve?
    @request.resolve!(method: "manual", reviewer: current_user, note: review_note)
    notify_reviewed(@request)
    respond_with_updated_row("Marked as resolved.")
  end

  def decline
    authorize! @request, to: :decline?
    @request.decline!(reviewer: current_user, note: review_note)
    notify_reviewed(@request)
    respond_with_updated_row("Request declined.")
  end

  private

  def set_request
    @request = ProfileChangeRequest.find(params[:id])
  end

  def requested_field
    ProfileChangeRequest::FIELDS.include?(params[:field]) ? params[:field] : "affiliation"
  end

  def review_note
    params[:reviewer_note].presence
  end

  def profile_change_request_params
    params.require(:profile_change_request).permit(
      :field, :requested_value, :details, :affiliation_id, :organization_id,
      :proposed_title, :proposed_start_date, :proposed_end_date, :proposed_organization_name
    )
  end

  def respond_with_updated_row(notice)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          ActionView::RecordIdentifier.dom_id(@request),
          partial: "profile_change_requests/request",
          locals: { request: @request }
        )
      end
      format.html { redirect_back fallback_location: profile_change_requests_path, notice: notice }
    end
  end

  def notify_admins_and_submitter(request)
    NotificationServices::CreateNotification.call(
      noticeable: request,
      recipient_role: :admin,
      recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
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
