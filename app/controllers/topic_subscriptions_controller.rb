class TopicSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_topic_subscription, only: [ :edit, :update, :destroy, :unsubscribe, :resubscribe ]

  def index
    authorize! TopicSubscription
    @topic_subscriptions = TopicSubscription
      .search_by_params(params)
      .includes(:topic_subscription_type, :interested_event, person: [ :user, { event_registrations: :event } ])
      .newest_first
      .paginate(page: params[:page], per_page: 25)
    render :topic_subscriptions_results if turbo_frame_request?
  end

  # This list gets pasted into a mail client, so it narrows the index's filter
  # rather than mirroring it: an unsubscribe holds whatever status was selected,
  # and people already registered for the event their subscription names have had
  # the interest answered. Both exclusions are opt-out via a toggle on the page.
  def email_addresses
    authorize! TopicSubscription, to: :index?
    @include_unsubscribed = params[:include_unsubscribed] == "1"
    @include_registered = params[:include_registered] == "1"

    matching = TopicSubscription
      .search_by_params(params)
      .includes(person: [ :user, :event_registrations ])
      .to_a

    still_subscribed = matching.select(&:active?)
    @unsubscribed_count = matching.size - still_subscribed.size

    candidates = @include_unsubscribed ? matching : still_subscribed
    answered, outstanding = candidates.partition(&:interest_already_answered?)
    @registered_count = answered.size

    @email_addresses = (@include_registered ? candidates : outstanding)
      .filter_map { |subscription| subscription.person.preferred_email.presence }
      .uniq
      .sort
  end

  def new
    authorize! TopicSubscription
    @topic_subscription = TopicSubscription.new(
      topic_subscription_type_id: new_topic_type_id,
      interested_event_id: params[:interested_event_id],
      person_id: params[:person_id]
    )
  end

  def create
    authorize! TopicSubscription
    @topic_subscription = TopicSubscription.new(topic_subscription_params)
    @topic_subscription.created_by = current_user
    @topic_subscription.updated_by = current_user

    if @topic_subscription.save
      redirect_to save_return_path, notice: "Subscription added."
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
      redirect_to save_return_path, notice: "Subscription updated."
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

    if @topic_subscription.resubscribe
      redirect_to topic_subscriptions_path, notice: "Resubscribed."
    else
      redirect_to topic_subscriptions_path,
        alert: "Can't resubscribe — this person #{@topic_subscription.errors.full_messages.to_sentence}."
    end
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
    params.require(:topic_subscription).permit(:person_id, :topic_subscription_type_id, :interested_event_id, :source, :note)
  end

  # Prefill the topic when opened from an event's Forms menu: an explicit type id
  # wins, then a stable key (e.g. "facilitator_trainings"), else the canonical
  # interested_in_more type.
  def new_topic_type_id
    return params[:topic_subscription_type_id] if params[:topic_subscription_type_id].present?

    type = params[:topic_key].present? ? TopicSubscriptionType.find_by(key: params[:topic_key]) : TopicSubscriptionType.interested_in_more
    type&.id
  end

  # When the form was opened from an event's Forms menu, return there; otherwise
  # fall back to the subscriptions index.
  def save_return_path
    helpers.topic_subscription_return_path
  end
end
