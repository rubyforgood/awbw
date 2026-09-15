class MembershipsController < ApplicationController
  before_action :set_person, only: [ :new, :create ]
  before_action :set_membership, only: [ :edit, :update ]

  def index
    authorize!

    if params[:person_id].present?
      @person = Person.find(params[:person_id])
      @memberships = @person.memberships
        .includes(membership_invoices: :allocations)
        .order(created_at: :desc)
        .decorate
    elsif turbo_frame_request?
      render_overview_section
    else
      load_overview_sections
      render :admin_index
    end
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

  SECTION_CONFIG = {
    overdue: "Overdue",
    within_grace: "Grace period",
    upcoming: "Upcoming",
    current: "Current"
  }.freeze

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

  # Admin overview sections

  def load_overview_sections(page: 1)
    @overdue_memberships = overview_section(:overdue, page: page)
    @within_grace_memberships = overview_section(:within_grace, page: page)
    @upcoming_memberships = overview_section(:upcoming, page: page)
    @current_memberships = overview_section(:current, page: page)
  end

  def overview_section(key, page:)
    authorized_scope(Membership.all)
      .not_cancelled
      .includes(:person, membership_invoices: :allocations)
      .references(:person)
      .public_send(key)
      .order("people.first_name", "people.last_name")
      .paginate(page: page, per_page: 25)
  end

  def render_overview_section
    frame_id = request.headers["Turbo-Frame"].to_s
    section_key = frame_id.sub("membership_overview_", "").to_sym

    unless SECTION_CONFIG.key?(section_key)
      load_overview_sections
      return render(:admin_index)
    end

    memberships = overview_section(section_key, page: params[:page])

    render partial: "memberships/admin_overview_section",
      locals: { section_key: section_key, title: SECTION_CONFIG[section_key], memberships: memberships }
  end
end
