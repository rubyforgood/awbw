class NotificationsController < ApplicationController
  before_action :set_notification, only: [ :show ]

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

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end
