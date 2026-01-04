class NotificationsController < ApplicationController
  before_action :set_notification, only: [ :show ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    @notifications =
      if current_user.super_user?
        Notification.all
      else
        Notification.where(recipient_email: current_user.email)
      end

    @notifications = @notifications
                       .includes(:noticeable)
                       .order(created_at: :desc)
                       .paginate(page: params[:page], per_page: per_page)
  end

  def show
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end
