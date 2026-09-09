class MembershipsController < ApplicationController
  before_action :set_person, only: [ :index, :new, :create ]
  before_action :set_membership, only: [ :edit, :update ]

  def index
    authorize!
    @memberships = @person.memberships
      .includes(membership_invoices: :allocations)
      .order(created_at: :desc)
      .decorate
  end

  def new
    authorize!
    @membership = @person.memberships.new
    @membership.membership_invoices.new(
      start_date: Date.current,
      cost_cents: Membership::ANNUAL_COST_CENTS
    )
  end

  def create
    authorize!
    @membership = @person.memberships.new(membership_params)

    if @membership.save
      redirect_to person_memberships_path(@person),
        notice: "Membership created. Autorenewal is turned on.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @membership
  end

  def update
    authorize! @membership

    if @membership.update(authorized_scope(params.require(:membership)))
      redirect_to person_memberships_path(@person),
        notice: update_notice, status: :see_other
    else
      redirect_to person_memberships_path(@person),
        alert: @membership.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def set_membership
    @membership = Membership.find(params[:id])
    @person = @membership.person
  end

  def membership_params
    params.expect(
      membership: [ :cost_dollars, { membership_invoices_attributes: [ [ :start_date, :cost_dollars ] ] } ]
    )
  end

  def update_notice
    return "Cost updated. Changes will only be applied to future years." unless @membership.saved_change_to_cancelled_at?
    return "Membership cancelled. Autorenewal turned off." if @membership.cancelled?

    "Membership resumed. Autorenewal turned back on."
  end
end
