class TopicSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_topic_subscription, only: [ :edit, :update, :destroy, :unsubscribe, :resubscribe ]

  def index
    authorize! TopicSubscription
    @topic_subscriptions = TopicSubscription
      .search_by_params(params)
      .includes(:interested_event, person: { event_registrations: :event })
      .newest_first
      .paginate(page: params[:page], per_page: 25)
    render :topic_subscriptions_results if turbo_frame_request?
  end

  def new
    authorize! TopicSubscription
    @topic_subscription = TopicSubscription.new(topic: "trainings", interested_event_id: params[:interested_event_id])
  end

  def create
    authorize! TopicSubscription
    @topic_subscription = TopicSubscription.new(topic_subscription_params)
    @topic_subscription.created_by = current_user
    @topic_subscription.updated_by = current_user

    if @topic_subscription.save
      redirect_to topic_subscriptions_path, notice: "Subscription added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @topic_subscription
  end

  def update
    authorize! @topic_subscription
    @topic_subscription.updated_by = current_user

    if @topic_subscription.update(topic_subscription_params)
      redirect_to topic_subscriptions_path, notice: "Subscription updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def unsubscribe
    authorize! @topic_subscription, to: :update?
    @topic_subscription.unsubscribe!
    redirect_to topic_subscriptions_path, notice: "Unsubscribed."
  end

  def resubscribe
    authorize! @topic_subscription, to: :update?
    @topic_subscription.resubscribe!
    redirect_to topic_subscriptions_path, notice: "Resubscribed."
  end

  def destroy
    authorize! @topic_subscription
    @topic_subscription.destroy
    redirect_to topic_subscriptions_path, notice: "Subscription removed."
  end

  private

  def set_topic_subscription
    @topic_subscription = TopicSubscription.find(params[:id])
  end

  def topic_subscription_params
    params.require(:topic_subscription).permit(:person_id, :topic, :interested_event_id, :source, :note)
  end
end
