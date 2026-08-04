class DuesSubscriptionsController < ApplicationController
  before_action :set_person

  def index
    authorize!
    @dues_subscriptions = @person.dues_subscriptions
      .includes(:dues_registrations)
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

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def dues_subscription_params
    params.expect(
      dues_subscription: [ :rate_dollars, { dues_registrations_attributes: [ [ :start_date, :cost_dollars ] ] } ]
    )
  end
end
