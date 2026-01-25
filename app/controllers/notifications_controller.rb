class NotificationsController < ApplicationController
  before_action :set_notification, only: [ :show ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    @notifications = authorized_scope(Notification)
                       .includes(:noticeable)
                       .order(created_at: :desc)
                       .paginate(page: params[:page], per_page: per_page)
  end

  def show
    authorize! @notification
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end
