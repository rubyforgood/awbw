class DuesSubscriptionsController < ApplicationController
  before_action :set_person, only: [ :index, :new, :create ]
  before_action :set_dues_subscription, only: [ :edit, :update ]

  def index
    authorize!
    @dues_subscriptions = @person.dues_subscriptions
      .includes(dues_registrations: :allocations)
      .order(created_at: :desc)
      .decorate
  end

  def new
    authorize!
    @dues_subscription = @person.dues_subscriptions.new
    @dues_subscription.dues_registrations.new(
      start_date: Date.current,
      cost_cents: Dues::ANNUAL_COST_CENTS
    )
  end

  def create
    authorize!
    @dues_subscription = @person.dues_subscriptions.new(dues_subscription_params)

    if @dues_subscription.save
      redirect_to person_dues_subscriptions_path(@person),
        notice: "Dues subscription created. Autorenewal is turned on.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @dues_subscription
  end

  def update
    authorize! @dues_subscription

    if @dues_subscription.update(authorized_dues_subscription_params)
      redirect_to person_dues_subscriptions_path(@person),
        notice: update_notice, status: :see_other
    else
      redirect_to person_dues_subscriptions_path(@person),
        alert: @dues_subscription.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def set_dues_subscription
    @dues_subscription = DuesSubscription.find(params[:id])
    @person = @dues_subscription.person
  end

  def dues_subscription_params
    params.expect(
      dues_subscription: [ :cost_dollars, { dues_registrations_attributes: [ [ :start_date, :cost_dollars ] ] } ]
    )
  end

  def authorized_dues_subscription_params
    authorized_scope(params.require(:dues_subscription))
  end

  def update_notice
    return "Cost updated. Changes will only be applied to future years." unless @dues_subscription.saved_change_to_cancelled_at?
    return "Subscription cancelled. Autorenewal turned off." if @dues_subscription.cancelled?

    "Subscription resumed. Autorenewal turned back on."
  end
end
