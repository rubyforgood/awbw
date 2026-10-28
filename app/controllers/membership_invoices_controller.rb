class MembershipInvoicesController < ApplicationController
  include AhoyTracking

  before_action :set_membership_invoice, only: %i[ show receipt edit update destroy charge ]

  STATUS_FILTERS = %w[all paid partial due overdue].freeze

  def index
    authorize!
    @status_filter = params[:status].presence_in(STATUS_FILTERS) || "all"
    @status_filters = STATUS_FILTERS

    if turbo_frame_request?
      @membership_invoices = filtered_invoices
        .order(start_date: :desc)
        .paginate(page: params[:page], per_page: params[:number_of_items_per_page].presence || 25)
      render :membership_invoices_results
    else
      @membership_invoices = filtered_invoices.order(start_date: :desc)
    end
  end

  def show
    authorize! @membership_invoice
    @invoice = MembershipInvoicePresenter.new(@membership_invoice)
    @deletion_blocked_reason = @membership_invoice.deletion_blocked_reason
    track_view("invoices", { membership_invoice_id: @membership_invoice.id })
  end

  def receipt
    authorize! @membership_invoice

    unless @membership_invoice.receipt_available?
      return redirect_to membership_invoice_path(@membership_invoice),
        alert: "A receipt is available once the invoice is paid in full.", status: :see_other
    end

    @receipt = MembershipInvoiceReceipt.new(@membership_invoice)
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

  def charge
    authorize! @membership_invoice, to: :charge?

    result = Membership::Autopay::Charge.call(invoice: @membership_invoice, actor: current_user)
    if result.success?
      redirect_to membership_invoice_path(@membership_invoice),
        notice: "Membership charged.", status: :see_other
    else
      redirect_to membership_invoice_path(@membership_invoice),
        alert: result.errors.to_sentence, status: :see_other
    end
  end

  private

  def filtered_invoices
    scope = MembershipInvoice
      .includes(:allocations, :charge_attempts, membership: :person)
      .by_person_name(params[:person_name])

    case @status_filter
    when "paid" then scope.paid_in_full
    when "partial" then scope.partially_paid
    when "due" then scope.not_paid_in_full.where(start_date: Date.current..)
    when "overdue" then scope.overdue
    else scope
    end
  end

  def set_membership_invoice
    @membership_invoice = MembershipInvoice
      .includes(:allocations, :charge_attempts, :invoicee, :bill_to_address, :attention_person,
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

  def invoice_details_params
    params.expect(membership_invoice: [
      :bill_to_organization_id, :bill_to_address_id, :hide_invoicee, :hide_address,
      :bill_to_additional_info, :attention_person_id, :cost_dollars
    ])
  end
end
