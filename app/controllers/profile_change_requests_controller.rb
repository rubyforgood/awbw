class ProfileChangeRequestsController < ApplicationController
  before_action :set_request, only: [ :approve, :decline, :resolve ]

  def index
    authorize! ProfileChangeRequest, to: :index?
    @status = ProfileChangeRequest::STATUSES.include?(params[:status]) ? params[:status] : "pending"
    @requests = authorized_scope(ProfileChangeRequest.all)
                  .where(status: @status)
                  .includes(:person, :requested_by, :reviewed_by)
                  .newest_first
  end

  def new
    @person = Person.find(params[:person_id])
    @request = @person.profile_change_requests.new(field: requested_field, requested_by: current_user)
    authorize! @request, to: :new?
  end

  def create
    @person = Person.find(params[:person_id])
    @request = @person.profile_change_requests.new(profile_change_request_params)
    @request.requested_by = current_user
    authorize! @request, to: :create?

    if @request.save
      notify_admins_and_submitter(@request)
      redirect_to edit_person_path(@person, anchor: "affiliations"),
                  notice: "Thanks — we've sent your change request to AWBW staff."
    else
      render :new, status: :unprocessable_content
    end
  end

  def approve
    authorize! @request, to: :approve?
    result = ProfileChangeRequests::Apply.call(request: @request, reviewer: current_user)

    if result.applied
      @request.resolve!(method: "approved", reviewer: current_user)
      redirect_back fallback_location: profile_change_requests_path, notice: "Approved. #{result.message}"
    else
      redirect_back fallback_location: profile_change_requests_path,
                    alert: "Couldn't apply automatically: #{result.message} Use \"Update manually\", then mark it resolved."
    end
  end

  def resolve
    authorize! @request, to: :resolve?
    @request.resolve!(method: "manual", reviewer: current_user)
    redirect_back fallback_location: profile_change_requests_path, notice: "Marked as resolved."
  end

  def decline
    authorize! @request, to: :decline?
    @request.decline!(reviewer: current_user)
    redirect_back fallback_location: profile_change_requests_path, notice: "Request declined."
  end

  private

  def set_request
    @request = ProfileChangeRequest.find(params[:id])
  end

  def requested_field
    ProfileChangeRequest::FIELDS.include?(params[:field]) ? params[:field] : "affiliation"
  end

  def profile_change_request_params
    params.require(:profile_change_request).permit(:field, :requested_value, :details)
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
end
