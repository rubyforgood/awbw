class NotificationsController < ApplicationController
  include AhoyTracking

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
      track_view("notifications", { page: "index" })
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
    track_view @notification
  end

  def update
    authorize! @notification
    responded_was = @notification.responded?
    body_was = @notification.email_body_text
    @notification.update!(notification_params)
    track_responded_change(responded_was)
    track_incoming_body_change(body_was)
    head :ok
  end

  def resend
    authorize! @notification, to: :resend?

    # Determine parent and root for the resend chain
    parent_id = @notification.id
    root_id = @notification.root_notification_id || @notification.id

    # Create and send a new notification using the service. Everything that shaped
    # the original body travels with it so the resend is the same email, not a
    # default-shaped one; only the provenance (sender, and `bulk` — a resend is an
    # individual action, not part of the original batch) reflects the resend itself.
    new_notification = NotificationServices::CreateNotification.call(
      noticeable: @notification.noticeable,
      kind: @notification.kind,
      recipient_email: @notification.recipient_email,
      recipient_role: @notification.recipient_role,
      notification_type: @notification.notification_type,
      custom_message: @notification.custom_message,
      custom_subject: @notification.custom_subject,
      hide_event_card: @notification.hide_event_card,
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

  def track_responded_change(previous)
    return if @notification.responded? == previous

    track_event("update.notification.responded", {
      resource_type: "Notification",
      resource_id: @notification.id,
      responded: @notification.responded?
    })
  end

  # An incoming communication is logged by hand, so an edit to its body is a real
  # content change worth surfacing — unlike outgoing/system messages, whose body
  # is generated, not authored.
  def track_incoming_body_change(previous)
    return unless @notification.incoming?
    return if @notification.email_body_text == previous

    track_event("update.notification.body", {
      resource_type: "Notification",
      resource_id: @notification.id
    })
  end

  def set_notification
    @notification = Notification.find(params[:id])
  end

  def notification_params
    params.require(:notification).permit(:responded, :channel, :email_subject, :email_body_text, :direction)
  end
end
