class People::MembershipsController < ApplicationController
  before_action :set_person, only: [ :index, :new, :create ]

  def index
    authorize! :membership, to: :index?

    @memberships = @person.memberships
      .includes(membership_invoices: :allocations)
      .order(created_at: :desc)
      .decorate
  end

  def new
    authorize! :membership, to: :new?

    @membership = @person.memberships.new
    @membership.membership_invoices.new(
      start_date: Date.current,
      cost_cents: Membership::ANNUAL_COST_CENTS
    )
  end

  def create
    authorize! :membership, to: :create?

    @membership = @person.memberships.new(membership_params)

    if @membership.save
      redirect_to person_memberships_path(@person),
        notice: "Membership created. Autorenewal is turned on.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def membership_params
    params.expect(
      membership: [ :cost_dollars, { membership_invoices_attributes: [ [ :start_date, :cost_dollars ] ] } ]
    )
  end
end
