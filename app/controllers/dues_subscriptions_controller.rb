class DuesSubscriptionsController < ApplicationController
  before_action :set_person, only: [ :index, :new, :create ]
  before_action :set_dues_subscription, only: [ :edit, :update, :cancel, :resume ]

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
        notice: "Dues subscription created.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @dues_subscription
  end

  def update
    authorize! @dues_subscription

    if @dues_subscription.update(rate_params)
      redirect_to person_dues_subscriptions_path(@person),
        notice: "Rate updated. It applies to future dues years.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def cancel
    authorize! @dues_subscription, to: :update?
    @dues_subscription.update!(cancelled_at: Time.current)

    redirect_to person_dues_subscriptions_path(@person),
      notice: "Subscription cancelled. They keep the dues year they have already paid for.",
      status: :see_other
  end

  def resume
    authorize! @dues_subscription, to: :update?
    @dues_subscription.update!(cancelled_at: nil)

    redirect_to person_dues_subscriptions_path(@person),
      notice: "Subscription resumed. Dues years will renew again.", status: :see_other
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
      dues_subscription: [ :rate_dollars, { dues_registrations_attributes: [ [ :start_date, :cost_dollars ] ] } ]
    )
  end

  def rate_params
    params.expect(dues_subscription: [ :rate_dollars ])
  end
end
