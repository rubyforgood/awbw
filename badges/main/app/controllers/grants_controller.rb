class GrantsController < ApplicationController
  include AhoyTracking
  before_action :set_grant, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    @grants = authorized_scope(Grant.all)
                .includes(:donor, scholarships: { allocation: :allocatable })
                .by_deadline
                .page(params[:page])
    track_index_intent(Grant, @grants, params)
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
