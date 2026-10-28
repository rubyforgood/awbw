class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[
    edit update destroy issue_next_invoice remove_next_year cancel_renewal resume_renewal
  ]

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

  def edit
    authorize! @membership
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

    result = Membership::UpdateTerm.call(
      membership: @membership,
      start_date: start_date,
      end_date: end_date,
      cost_cents: parse_cents(attrs[:cost_dollars]),
      renewal_on: @membership.renewal_on?
    )

    if result.success?
      redirect_to person_memberships_path(@person),
        notice: "Membership updated.", status: :see_other
    else
      redirect_to edit_membership_path(@membership),
        alert: result.errors.to_sentence, status: :see_other
    end
  end

  def destroy
    authorize! @membership

    if @membership.deletable?
      @membership.destroy!
      redirect_to person_memberships_path(@person),
        notice: "Membership deleted.", status: :see_other
    else
      redirect_to person_memberships_path(@person),
        alert: "Cannot delete this membership because #{@membership.deletion_blocked_reason}.",
        status: :see_other
    end
  end

  def issue_next_invoice
    authorize! @membership, to: :issue_next_invoice?

    result = Membership::Renew.call(membership: @membership, force: true)
    if result.success?
      redirect_to person_memberships_path(@person),
        notice: "Next membership invoice issued.", status: :see_other
    else
      redirect_to person_memberships_path(@person),
        alert: result.errors.to_sentence, status: :see_other
    end
  end

  def remove_next_year
    authorize! @membership, to: :remove_next_year?

    result = Membership::RemoveNextYear.call(membership: @membership)
    if result.success?
      redirect_to person_memberships_path(@person),
        notice: "Next year removed. Renewal is now off.", status: :see_other
    else
      redirect_to person_memberships_path(@person),
        alert: result.errors.to_sentence, status: :see_other
    end
  end

  def cancel_renewal
    authorize! @membership, to: :cancel_renewal?

    @membership.update!(autorenewal_cancelled_at: Time.current)
    redirect_to person_memberships_path(@person),
      notice: "Renewal turned off. The current term still stands.", status: :see_other
  end

  def resume_renewal
    authorize! @membership, to: :resume_renewal?

    @membership.update!(autorenewal_cancelled_at: nil)
    redirect_to person_memberships_path(@person),
      notice: "Renewal turned back on. The next invoice will be issued in the renewal window.",
      status: :see_other
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

  def parse_cents(value)
    return if value.blank?

    (value.to_d * 100).to_i
  end
end
