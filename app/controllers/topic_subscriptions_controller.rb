class TopicSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_topic_subscription, only: [ :edit, :update, :destroy, :unsubscribe, :resubscribe, :toggle_marked, :save_note ]

  def index
    authorize! TopicSubscription
    # The active/unsubscribed segmented toggle owns the status axis (default
    # active), so exclude status from the shared filter and apply it here.
    base = TopicSubscription
      .search_by_params(params.except(:status))
      .includes(:topic_subscription_type, :interested_event, :organization, :comments, person: [ :user, { event_registrations: :event } ])

    @active_count = base.active.count
    @unsubscribed_count = base.unsubscribed.count
    @status_filter = params[:status].presence == "unsubscribed" ? "unsubscribed" : "active"

    scope = @status_filter == "unsubscribed" ? base.unsubscribed : base.active

    # Only the marked column is click-to-sort; every other view defaults to
    # newest-first. A marked sort keeps newest-first as its tiebreak.
    @sort = params[:sort] == "marked" ? "marked" : "subscribed_at"
    @sort_direction = params[:direction] == "asc" ? "asc" : "desc"
    ordered = @sort == "marked" ? scope.reorder(marked: @sort_direction, subscribed_at: :desc) : scope.newest_first

    @topic_subscriptions = ordered.paginate(page: params[:page], per_page: 25)
    @mark_column_label = mark_column_label
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
      organization_id: params[:organization_id],
      person_id: params[:person_id]
    )
  end

  def create
    authorize! TopicSubscription
    @topic_subscription = TopicSubscription.new(topic_subscription_params)

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

  def toggle_marked
    authorize! @topic_subscription, to: :update?
    @topic_subscription.update!(marked: ActiveModel::Type::Boolean.new.cast(params[:value]))
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to topic_subscriptions_path }
    end
  end

  def save_note
    authorize! @topic_subscription, to: :update?
    @topic_subscription.save_index_note(params[:note])
    head :ok
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

  # When the list is filtered to a single topic, the Mark column header takes that
  # topic's configured label; otherwise it stays the generic "Mark".
  def mark_column_label
    return "Mark" if params[:topic_subscription_type_id].blank?

    TopicSubscriptionType.where(id: params[:topic_subscription_type_id]).pick(:mark_label).presence || "Mark"
  end

  def topic_subscription_params
    permitted = params.require(:topic_subscription).permit(:person_id, :topic_subscription_type_id, :interested_event_id, :organization_id, :source, :marked,
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: [ :id, :channel, :sender_id, :email_subject, :email_body_text, :direction, :responded, :noticeable_type, :noticeable_id, :_destroy ],
      person_attributes: [ :first_name, :last_name, :email ])

    # The new-person toggle is CSS-only, so both the person select and the new
    # person fields submit. Keep only the chosen mode's params so we never build
    # a stray person or ignore the picked one.
    if params[:person_source_mode] == "new"
      permitted.except(:person_id)
    else
      permitted.except(:person_attributes)
    end
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
