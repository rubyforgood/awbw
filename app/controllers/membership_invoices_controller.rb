class MembershipInvoicesController < ApplicationController
  include AhoyTracking

  before_action :set_membership, only: [ :new, :create ]
  before_action :set_membership_invoice, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    @membership_invoices = MembershipInvoice
      .includes(:allocations, membership: :person)
      .by_person_name(params[:person_name])
      .order(start_date: :desc)
      .paginate(page: params[:page], per_page: params[:number_of_items_per_page].presence || 25)

    render :membership_invoices_results if turbo_frame_request?
  end

  def new
    authorize!
    @membership_invoice = @membership.membership_invoices.new(
      start_date: next_start_date,
      cost_cents: @membership.cost_cents || Membership.annual_cost_cents
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
    @invoice = MembershipInvoicePresenter.new(@membership_invoice)
    @deletion_blocked_reason = @membership_invoice.deletion_blocked_reason
    track_view("invoices", { membership_invoice_id: @membership_invoice.id })
  end

  def edit
    authorize! @membership_invoice
    set_invoice_detail_options
  end

  def update
    authorize! @membership_invoice

    if @membership_invoice.update(invoice_details_params)
      redirect_to membership_invoice_path(@membership_invoice),
        notice: "Invoice details updated.", status: :see_other
    else
      set_invoice_detail_options
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @membership_invoice
    person = @membership_invoice.person

    if @membership_invoice.deletable?
      @membership_invoice.destroy!
      redirect_to person_memberships_path(person),
        notice: "Membership invoice deleted.", status: :see_other
    else
      redirect_to person_memberships_path(person),
        alert: "Cannot delete this invoice because #{@membership_invoice.deletion_blocked_reason}.",
        status: :see_other
    end
  end

  private

  def set_membership
    @membership = Membership.find(params[:membership_id])
  end

  def set_membership_invoice
    @membership_invoice = MembershipInvoice
      .includes(:allocations, :invoicee, :bill_to_address, :attention_person,
                membership: :person, created_by: :person, updated_by: :person)
      .find(params[:id])
  end

  def set_invoice_detail_options
    @bill_to_organizations = bill_to_organizations
    @bill_to_address_options = bill_to_address_options
  end

  def bill_to_organizations
    organizations = @membership_invoice.person.affiliations.active_or_pending
      .includes(:organization)
      .map(&:organization)
      .compact

    current = @membership_invoice.invoicee
    organizations << current if current.is_a?(Organization)

    organizations.uniq.sort_by(&:name)
  end

  def bill_to_address_options
    owners = [ @membership_invoice.person ] + @bill_to_organizations

    owners.flat_map do |owner|
      owner.addresses.active.order(invoice_address: :desc, id: :desc).map do |address|
        [ "#{owner.respond_to?(:full_name) ? owner.full_name : owner.name} — #{address.decorate.picker_label}", address.id ]
      end
    end
  end

  def next_start_date
    latest_end = @membership.membership_invoices.maximum(:end_date)
    latest_end ? latest_end + 1.day : Date.current
  end

  def membership_invoice_params
    params.expect(membership_invoice: [ :start_date, :cost_dollars ])
  end

  def invoice_details_params
    params.expect(membership_invoice: [
      :bill_to_organization_id, :bill_to_address_id, :hide_invoicee, :hide_address,
      :bill_to_additional_info, :attention_person_id
    ])
  end
end
