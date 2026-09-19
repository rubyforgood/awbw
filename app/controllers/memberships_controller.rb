class MembershipsController < ApplicationController
  before_action :set_membership, only: [ :edit, :update, :destroy ]

  def index
    authorize!

    if turbo_frame_request?
      render_overview_section
    else
      render :admin_index
    end
  end

  def show
    @membership = Membership.find(params[:id]).decorate
    authorize! @membership
    @invoices = @membership.membership_invoices.includes(:allocations)

    respond_to do |format|
      format.html
      format.turbo_stream
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

  SECTION_CONFIG = Membership::OVERVIEW_SECTIONS

  def set_membership
    @membership = Membership.find(params[:id])
    @person = @membership.person
  end

  def update_notice
    return "Cost updated. Changes will only be applied to future years." unless @membership.saved_change_to_autorenewal_cancelled_at?
    return "Membership cancelled. Autorenewal turned off." if @membership.autorenewal_cancelled?

    "Membership resumed. Autorenewal turned back on."
  end

  # Admin overview sections

  def overview_section(key, page:)
    authorized_scope(Membership.all)
      .autorenewal_not_cancelled
      .includes(person: :user, membership_invoices: :allocations)
      .references(:person)
      .public_send(key)
      .order("people.first_name", "people.last_name")
      .paginate(page: page, per_page: 10)
  end

  def render_overview_section
    section_key = params[:section]&.to_sym
    section_key = :overdue unless SECTION_CONFIG.key?(section_key)

    memberships = overview_section(section_key, page: params[:page])

    render "memberships/memberships_results",
      locals: { section_key: section_key, memberships: memberships }
  end
end
