class GrantsController < ApplicationController
  include AhoyTracking
  before_action :set_grant, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!

    # Scoped to a single funder when linked from a person/org edit page. Resolve
    # the funder from a matching grant (avoids reflection on the type param) so the
    # header banner can name it; filter_grants scopes the rows to the same funder.
    if params[:funder_id].present? && Grant::FUNDER_TYPES.include?(params[:funder_type])
      @funder = authorized_scope(Grant.all)
                 .where(funder_id: params[:funder_id], funder_type: params[:funder_type])
                 .first&.funder
    end

    # The full page renders only the header, filters, and an empty results frame;
    # the frame's src request (turbo_frame_request?) loads the filtered rows.
    if turbo_frame_request?
      @grants = filter_grants(authorized_scope(Grant.all))
                  .includes(:funder, scholarships: { allocation: :allocatable })
                  .by_deadline
                  .page(params[:page])
      track_index_intent(Grant, @grants, params)
      render :grants_results
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
    set_tag_collections
  end

  def edit
    authorize! @grant
    set_scholarships
    set_tag_collections
  end

  def create
    @grant = Grant.new(grant_params)
    @grant.created_by = current_user
    @grant.updated_by = current_user
    authorize! @grant

    if @grant.save
      redirect_to @grant, notice: "Grant was successfully created."
    else
      set_tag_collections
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
      set_tag_collections
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

  private

  # Narrow the index by the optional filter inputs. Each filter is a no-op when
  # its param is blank or unrecognized, so combinations stack cleanly.
  def filter_grants(scope)
    scope = scope.where("grants.name LIKE ?", "%#{Grant.sanitize_sql_like(params[:name])}%") if params[:name].present?
    scope = filter_by_funder_name(scope, params[:funder_name]) if params[:funder_name].present?

    scope = case params[:funds]
    when "available" then scope.with_funds_remaining
    when "none" then scope.fully_issued
    else scope
    end

    scope = scope.where(funder_type: params[:funder_type]) if Grant::FUNDER_TYPES.include?(params[:funder_type])
    scope = scope.where(funder_id: params[:funder_id]) if params[:funder_id].present?

    # Sector/category filters back the "View all grants" deep link from the
    # taggings browse page (see TaggingsHelper#tagged_index_path).
    scope = scope.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    scope = scope.category_names_all(params[:category_names_all]) if params[:category_names_all].present?

    case params[:tasks]
    when "completed" then scope.all_tasks_completed
    when "outstanding" then scope.tasks_outstanding
    else scope
    end
  end

  # Match grants whose polymorphic funder (Organization or Person) name contains
  # the query. Resolve matching funder ids per type, then OR the two sides so the
  # other active filters on `scope` apply to both.
  def filter_by_funder_name(scope, query)
    like = "%#{Grant.sanitize_sql_like(query)}%"
    org_ids = Organization.where("name LIKE ?", like).pluck(:id)
    person_ids = Person.where("first_name LIKE :q OR last_name LIKE :q OR CONCAT(first_name, ' ', last_name) LIKE :q", q: like).pluck(:id)
    scope.where(funder_type: "Organization", funder_id: org_ids)
         .or(scope.where(funder_type: "Person", funder_id: person_ids))
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

  # Sector chips and the grouped category checkboxes on the grant form.
  def set_tag_collections
    @sectors = Sector.published.order(:name)
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || (type.published? && !type.story_specific? && !type.profile_specific?) }
        .sort_by { |type, _| type&.name.to_s.downcase }
  end

  def grant_params
    params.require(:grant).permit(
      :name, :description, :amount_dollars, :amount_cents, :funder_sgid,
      :funds_allocation_deadline, :funds_received_on, :eligibility_criteria, :tasks,
      sector_ids: [], category_ids: []
    )
  end
end
