class NotificationsController < ApplicationController
  before_action :set_notification, only: [ :show, :update, :resend ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Notification.includes(:noticeable, sender: :person))
      filtered = base_scope.search_by_params(params.to_unsafe_h)
      @notifications = filtered.order(created_at: :desc)
                               .paginate(page: params[:page], per_page: per_page)

      render :notifications_results
    else
      render :index
    end
  end

  def new
    authorize! Notification, to: :new?
    @notification = Notification.new
  end

  # Log a communication by hand against a person — mirrors the nested
  # notifications flow (people_controller#update): the picked person is the
  # noticeable and supplies the recipient_email; the model fills in the
  # manual_log defaults (kind, recipient_role, notification_type, delivered_at).
  def create
    authorize! Notification, to: :create?

    @person = Person.find_by(id: params[:person_id])
    @notification = Notification.new(notification_params)
    @notification.sender = current_user

    if @person
      @notification.noticeable = @person
      @notification.recipient_email = @person.communications_email.presence || "n/a"
    else
      @notification.errors.add(:base, "Select a person to log this communication against")
    end

    if @person && @notification.save
      redirect_to notifications_path, notice: "Communication logged."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    authorize! @notification
  end

  def update
    authorize! @notification
    @notification.update!(notification_params)
    head :ok
  end

  def resend
    authorize! @notification, to: :resend?

    # Determine parent and root for the resend chain
    parent_id = @notification.id
    root_id = @notification.root_notification_id || @notification.id

    # Create and send a new notification using the service
    new_notification = NotificationServices::CreateNotification.call(
      noticeable: @notification.noticeable,
      kind: @notification.kind,
      recipient_email: @notification.recipient_email,
      recipient_role: @notification.recipient_role,
      notification_type: @notification.notification_type,
      sender: current_user, # a resend is an admin action — attribute it to them
      deliver: true,
      persist_delivered_email: true
    )

    # Set parent and root notification IDs to track the resend chain
    new_notification.update!(
      parent_notification_id: parent_id,
      root_notification_id: root_id
    )

    redirect_to @notification, notice: t("communications.resent")
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end

  def notification_params
    params.require(:notification).permit(:responded, :channel, :email_subject, :email_body_text)
  end
end
