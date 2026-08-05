class TopicSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_topic_subscription, only: [ :edit, :update, :destroy, :unsubscribe, :resubscribe ]

  def index
    authorize! TopicSubscription
    # The active/unsubscribed segmented toggle owns the status axis (default
    # active), so exclude status from the shared filter and apply it here.
    base = TopicSubscription
      .search_by_params(params.except(:status))
      .includes(:topic_subscription_type, :interested_event, person: [ :user, { event_registrations: :event } ])

    @active_count = base.active.count
    @unsubscribed_count = base.unsubscribed.count
    @status_filter = params[:status].presence == "unsubscribed" ? "unsubscribed" : "active"

    scope = @status_filter == "unsubscribed" ? base.unsubscribed : base.active
    @topic_subscriptions = scope.newest_first.paginate(page: params[:page], per_page: 25)
    render :topic_subscriptions_results if turbo_frame_request?
  end

  # This list gets pasted into a mail client, so it narrows the index's filter
  # rather than mirroring it: an unsubscribe holds whatever status was selected,
  # and people already registered for the event their subscription names have had
  # the interest answered. Both exclusions are opt-out via a toggle on the page —
  # so the index's status param must not narrow the base query (it rides along on
  # the link here), or an incoming status=active would leave the unsubscribed
  # toggle with nobody to add back.
  def email_addresses
    authorize! TopicSubscription, to: :index?
    @include_unsubscribed = params[:include_unsubscribed] == "1"
    @include_registered = params[:include_registered] == "1"

    matching = TopicSubscription
      .search_by_params(params.except(:status))
      .includes(person: [ :user, :event_registrations ])
      .to_a

    @email_addresses = reachable_emails(matching, unsubscribed: @include_unsubscribed, registered: @include_registered)

    # Each toggle reports the addresses switching it on would *add*, not the
    # subscriptions it hides — someone still reachable through another
    # subscription isn't left out, and counting rows would overstate both.
    @unsubscribed_count = (reachable_emails(matching, unsubscribed: true, registered: @include_registered) - @email_addresses).size
    @registered_count = (reachable_emails(matching, unsubscribed: @include_unsubscribed, registered: true) - @email_addresses).size
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
    redirect_to save_return_path, notice: "Unsubscribed."
  end

  def resubscribe
    authorize! @topic_subscription, to: :update?

    if @topic_subscription.resubscribe
      redirect_to save_return_path, notice: "Resubscribed."
    else
      redirect_to save_return_path,
        alert: "Can't resubscribe — this person #{@topic_subscription.errors.full_messages.to_sentence}."
    end
  end

  def destroy
    authorize! @topic_subscription
    @topic_subscription.destroy
    redirect_to save_return_path, notice: "Subscription removed."
  end

  private

  # The distinct addresses reachable from these subscriptions under the two
  # opt-in widenings. Deduped by address, since one person can hold several
  # subscriptions and only needs to be emailed once.
  def reachable_emails(subscriptions, unsubscribed:, registered:)
    scoped = unsubscribed ? subscriptions : subscriptions.select(&:active?)
    scoped = scoped.reject(&:interest_already_answered?) unless registered
    scoped.filter_map { |subscription| subscription.person.preferred_email.presence }.uniq.sort
  end

  def set_topic_subscription
    @topic_subscription = TopicSubscription.find(params[:id])
  end

  def topic_subscription_params
    params.require(:topic_subscription).permit(:person_id, :topic_subscription_type_id, :interested_event_id, :source,
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ])
  end

  # Prefill the topic when opened from an event's Forms menu: an explicit type id
  # wins, then a stable key (e.g. "facilitator_trainings"), else the canonical
  # interested_in_more type.
  def new_topic_type_id
    return params[:topic_subscription_type_id] if params[:topic_subscription_type_id].present?

    type = params[:topic_key].present? ? TopicSubscriptionType.find_by(key: params[:topic_key]) : TopicSubscriptionType.interested_in_more
    type&.id
  end

  # Back to wherever this subscription was opened from — the filtered index, an
  # event's Forms menu, or a person — falling back to the subscriptions index.
  # Shared with the eyebrow so the redirect and the back link never diverge.
  def save_return_path
    helpers.topic_subscription_return_path
  end
end
