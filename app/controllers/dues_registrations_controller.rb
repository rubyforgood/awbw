class DuesRegistrationsController < ApplicationController
  before_action :set_dues_subscription, only: [ :new, :create ]
  before_action :set_dues_registration, only: [ :edit, :update ]

  def index
    authorize!
    @dues_registrations = DuesRegistration
      .includes(:allocations, dues_subscription: :person)
      .order(start_date: :desc)
      .paginate(page: params[:page], per_page: params[:number_of_items_per_page].presence || 25)

    render :dues_registrations_results if turbo_frame_request?
  end

  def new
    authorize!
    @dues_registration = @dues_subscription.dues_registrations.new(
      start_date: next_start_date,
      cost_cents: @dues_subscription.rate_cents || Dues::ANNUAL_COST_CENTS
    )
  end

  def create
    authorize!
    @dues_registration = @dues_subscription.dues_registrations.new(dues_registration_params)

    if @dues_registration.save
      redirect_to person_dues_subscriptions_path(@dues_subscription.person),
        notice: "Annual dues log created.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @dues_registration
  end

  def update
    authorize! @dues_registration

    if @dues_registration.update(dues_registration_params)
      redirect_to person_dues_subscriptions_path(@dues_registration.person),
        notice: "Annual dues log updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_dues_subscription
    @dues_subscription = DuesSubscription.find(params[:dues_subscription_id])
  end

  def set_dues_registration
    @dues_registration = DuesRegistration.find(params[:id])
  end

  def next_start_date
    latest_end = @dues_subscription.dues_registrations.maximum(:end_date)
    latest_end ? latest_end + 1.day : Date.current
  end

  def dues_registration_params
    params.expect(dues_registration: [ :start_date, :end_date, :cost_dollars ])
  end
end
