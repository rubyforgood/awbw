class GrantsController < ApplicationController
  include AhoyTracking
  before_action :set_grant, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!

    # The full page renders only the header, filters, and an empty results frame;
    # the frame's src request (turbo_frame_request?) loads the filtered rows.
    if turbo_frame_request?
      @grants = filter_grants(authorized_scope(Grant.all))
                  .includes(:donor, scholarships: { allocation: :allocatable })
                  .by_deadline
                  .page(params[:page])
      track_index_intent(Grant, @grants, params)
      render :grant_results
    else
      render :index
    end
  end

  def show
    authorize! @grant
    set_scholarships
    track_view(@grant)
  end

  def new
    @grant = Grant.new
    authorize! @grant
    set_form_variables
  end

  def edit
    authorize! @grant
    set_scholarships
    set_form_variables
  end

  def create
    @grant = Grant.new(grant_params)
    @grant.created_by = current_user
    @grant.updated_by = current_user
    authorize! @grant

    if @grant.save
      redirect_to @grant, notice: "Grant was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @grant
    @grant.updated_by = current_user

    if @grant.update(grant_params)
      redirect_to @grant, notice: "Grant was successfully updated.", status: :see_other
    else
      set_scholarships
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @grant

    if @grant.destroy
      redirect_to grants_path, notice: "Grant was successfully destroyed."
    else
      redirect_to @grant, alert: "Can't delete a grant that has associated scholarships. Remove its scholarships first.", status: :see_other
    end
  end

  def set_form_variables
    @donor_options = {
      "Organizations" => Organization.order(:name).map { |o| [ o.name, o.to_signed_global_id.to_s ] },
      "People" => Person.order(:last_name, :first_name).map { |p| [ p.full_name, p.to_signed_global_id.to_s ] }
    }
  end

  private

  # Narrow the index by the optional filter inputs. Each filter is a no-op when
  # its param is blank or unrecognized, so combinations stack cleanly.
  def filter_grants(scope)
    scope = scope.where("grants.name LIKE ?", "%#{Grant.sanitize_sql_like(params[:name])}%") if params[:name].present?
    scope = filter_by_donor_name(scope, params[:donor_name]) if params[:donor_name].present?

    scope = case params[:funds]
    when "available" then scope.with_funds_remaining
    when "none" then scope.fully_issued
    else scope
    end

    scope = scope.where(donor_type: params[:donor_type]) if Grant::DONOR_TYPES.include?(params[:donor_type])

    case params[:tasks]
    when "completed" then scope.all_tasks_completed
    when "outstanding" then scope.tasks_outstanding
    else scope
    end
  end

  # Match grants whose polymorphic donor (Organization or Person) name contains
  # the query. Resolve matching donor ids per type, then OR the two sides so the
  # other active filters on `scope` apply to both.
  def filter_by_donor_name(scope, query)
    like = "%#{Grant.sanitize_sql_like(query)}%"
    org_ids = Organization.where("name LIKE ?", like).pluck(:id)
    person_ids = Person.where("first_name LIKE :q OR last_name LIKE :q OR CONCAT(first_name, ' ', last_name) LIKE :q", q: like).pluck(:id)
    scope.where(donor_type: "Organization", donor_id: org_ids)
         .or(scope.where(donor_type: "Person", donor_id: person_ids))
  end

  def set_grant
    @grant = Grant.find(params[:id])
  end

  def set_scholarships
    @scholarships = @grant.scholarships
                          .includes(:recipient)
                          .order(created_at: :desc)
                          .paginate(page: params[:page], per_page: 10)
  end

  def grant_params
    params.require(:grant).permit(
      :name, :description, :amount_dollars, :amount_cents, :donor_sgid,
      :application_deadline, :funds_received_on, :eligibility_criteria, :tasks
    )
  end
end
