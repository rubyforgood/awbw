class MembershipsController < ApplicationController
  before_action :set_membership, only: [ :edit, :update, :destroy ]

  def index
    authorize!
    @status = status_filter

    if turbo_frame_request?
      @memberships = directory_memberships
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

    if @membership.update(authorized_scope(params.require(:membership)))
      redirect_to person_memberships_path(@person),
        notice: update_notice, status: :see_other
    else
      redirect_to person_memberships_path(@person),
        alert: @membership.errors.full_messages.to_sentence, status: :see_other
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

  private

  def set_membership
    @membership = Membership.find(params[:id])
    @person = @membership.person
  end

  def update_notice
    return "Cost updated. Changes will only be applied to future years." unless @membership.saved_change_to_autorenewal_cancelled_at?
    return "Membership cancelled. Autorenewal turned off." if @membership.autorenewal_cancelled?

    "Membership resumed. Autorenewal turned back on."
  end

  def directory_memberships
    scope = authorized_scope(Membership.all)
      .includes(person: [ :user, { pay_customers: :subscriptions } ], membership_invoices: :allocations)
      .by_person_name(params[:person_name])
    scope = scope.public_send(status_filter) unless status_filter == "all"

    scope.order(start_date: :desc).paginate(page: params[:page], per_page: 25)
  end

  def status_filter
    params[:status].presence_in(Membership::DIRECTORY_STATUSES) || "active"
  end
end
