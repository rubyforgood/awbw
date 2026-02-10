class NotificationsController < ApplicationController
  before_action :set_notification, only: [ :show, :resend ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(Notification.includes(:noticeable))
    filtered = base_scope.search_by_params(params.to_unsafe_h)
    @notifications = filtered.order(created_at: :desc)
                             .paginate(page: params[:page], per_page: per_page)
  end

  def show
    authorize! @notification
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
      deliver: true,
      persist_delivered_email: true
    )

    # Set parent and root notification IDs to track the resend chain
    new_notification.update!(
      parent_notification_id: parent_id,
      root_notification_id: root_id
    )

    redirect_to @notification, notice: "Notification email has been resent successfully."
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end
