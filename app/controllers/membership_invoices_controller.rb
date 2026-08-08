class MembershipInvoicesController < ApplicationController
  before_action :set_membership, only: [ :new, :create ]
  before_action :set_membership_invoice, only: [ :show, :edit, :update ]

  def index
    authorize!
    @membership_invoices = MembershipInvoice
      .includes(:allocations, membership: :person)
      .order(start_date: :desc)
      .paginate(page: params[:page], per_page: params[:number_of_items_per_page].presence || 25)

    render :membership_invoices_results if turbo_frame_request?
  end

  def new
    authorize!
    @membership_invoice = @membership.membership_invoices.new(
      start_date: next_start_date,
      cost_cents: @membership.cost_cents || Membership::ANNUAL_COST_CENTS
    )
  end

  def create
    authorize!
    @membership_invoice = @membership.membership_invoices.new(membership_invoice_params)

    if @membership_invoice.save
      redirect_to person_memberships_path(@membership.person),
        notice: "Membership invoice created.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    authorize! @membership_invoice
    redirect_to person_memberships_path(@membership_invoice.registrant), status: :see_other
  end

  def edit
    authorize! @membership_invoice
  end

  def update
    authorize! @membership_invoice

    if @membership_invoice.update(membership_invoice_params)
      redirect_to person_memberships_path(@membership_invoice.person),
        notice: "Membership invoice updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_membership
    @membership = Membership.find(params[:membership_id])
  end

  def set_membership_invoice
    @membership_invoice = MembershipInvoice.find(params[:id])
  end

  def next_start_date
    latest_end = @membership.membership_invoices.maximum(:end_date)
    latest_end ? latest_end + 1.day : Date.current
  end

  def membership_invoice_params
    params.expect(membership_invoice: [ :start_date, :end_date, :cost_dollars ])
  end
end
