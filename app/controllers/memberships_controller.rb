class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[ show edit update destroy ]

  def index
    authorize!
    @status_filter = params[:status].presence_in(Membership::DIRECTORY_STATUSES) || "active"

    if turbo_frame_request?
      scope = Membership.all
        .includes(person: :user, membership_invoices: :allocations)
        .by_person_name(params[:person_name])
      scope = scope.public_send(@status_filter) unless @status_filter == "all"
      @memberships = scope.order(start_date: :desc).paginate(page: params[:page], per_page: 25)
      render "memberships/memberships_results"
    else
      render :index
    end
  end

  def show
    authorize! @membership
    @membership_invoices = @membership.membership_invoices.includes(:allocations, :charge_attempts).to_a
    @reconciliation_invoices = if allowed_to?(:manage?, @membership)
      @membership.membership_invoices.needing_reconciliation
        .includes(:allocations, charge_attempts: :pay_charge)
        .to_a
    else
      []
    end
    @next_invoice = @membership.next_invoice
    @has_card = @person.stripe_customer&.payment_methods&.exists? || false
    @renewal_blocked_reason = @membership.renewal_blocked_reason
    @deletable = @membership.deletable?
    @discardable = @membership.discardable?
  end

  def edit
    authorize! @membership
    @invoice_coverage_start = @membership.invoice_coverage_start
    @invoice_coverage_end = @membership.invoice_coverage_end
  end

  def update
    authorize! @membership

    attrs = params[:membership] || {}
    start_date = parse_date(attrs[:start_date])
    end_date = parse_date(attrs[:end_date])
    unless start_date && end_date
      return redirect_to edit_membership_path(@membership),
        alert: "Enter both a start and an end date.", status: :see_other
    end

    cost_cents = MoneyParser.cents(attrs[:cost_dollars])
    if MoneyParser.invalid?(cost_cents)
      return redirect_to edit_membership_path(@membership),
        alert: "Enter the locked price as a number, e.g. 100 or 99.50.", status: :see_other
    end

    result = Membership::UpdateTerm.call(
      membership: @membership,
      start_date: start_date,
      end_date: end_date,
      cost_cents: cost_cents
    )

    if result.success?
      redirect_to membership_path(@membership),
        notice: "Membership updated.", status: :see_other
    else
      redirect_to edit_membership_path(@membership),
        alert: result.errors.to_sentence, status: :see_other
    end
  end

  def destroy
    authorize! @membership

    result = Membership::Discard.call(membership: @membership)
    if result.success?
      redirect_to person_memberships_path(@person),
        notice: "Membership deleted.", status: :see_other
    else
      redirect_to membership_path(@membership),
        alert: result.errors.to_sentence, status: :see_other
    end
  end

  private

  def set_membership
    @membership = Membership.find(params[:id])
    @person = @membership.person
  end

  def parse_date(value)
    return if value.blank?

    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end
end
