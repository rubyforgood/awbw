class FacilitatorsController < ApplicationController
  before_action :set_facilitator, only: %i[ show edit update destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    facilitators = Facilitator
                     .searchable
                     .search_by_params(params.to_unsafe_h)
                     .includes(:user).references(:user)
                     .order(:first_name, :last_name)
    @count_display = facilitators.size
    @facilitators = facilitators.paginate(page: params[:page], per_page: per_page)
  end

  def show
    @facilitator = Facilitator.find(params[:id]).decorate
    @facilitator.increment_view_count!(session: session, request: request)
  end

  def new
    set_user
    @facilitator = @user ? FacilitatorFromUserService.new(user: @user).call : Facilitator.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @facilitator = Facilitator.new(facilitator_params.except(:user_attributes))
    @facilitator.user ||= (User.find(params[:facilitator][:user_attributes][:id]) if params[:facilitator][:user_attributes])

    respond_to do |format|
      if @facilitator.save
        format.html { redirect_to @facilitator, notice: "Facilitator was successfully created." }
      else
        set_form_variables
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if @facilitator.update(facilitator_params)
        format.html { redirect_to @facilitator, notice: "Facilitator was successfully updated." }
      else
        set_form_variables
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @facilitator.destroy

    respond_to do |format|
      format.html { redirect_to facilitators_path, status: :see_other, notice: "Facilitator was successfully destroyed." }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_facilitator
      @facilitator = Facilitator.find(params[:id])
    end

    def set_user
      if params[:user_id].present?
        @user ||= User.find_by(id: params[:user_id])
        if @user
          @facilitator&.user ||= @user
          @user.facilitator ||= @facilitator
        end
      end
    end

    def set_form_variables
      set_user
      # @facilitator.build_user if @facilitator.user.blank? # Build a fresh one if missing

      if @facilitator.user
        @facilitator.user.project_users.first || @facilitator.user.project_users.build
      end
      projects = if current_user.super_user?
                   Project.active
      else
                   current_user.projects
      end
      @projects_array = projects.order(:name).pluck(:name, :id)
    end


    # Only allow a list of trusted parameters through.
    def facilitator_params
      params.require(:facilitator).permit(
        :avatar,
        :first_name, :last_name,
        :email, :email_type,
        :email_2, :email_2_type,
        :street_address, :city, :state, :zip, :country, :mailing_address_type,
        :best_time_to_call,
        :date_of_birth,
        :bio, :notes,
        :display_name_preference,
        :pronouns,
        :profile_show_name_preference,
        :profile_is_searchable,
        :profile_show_pronouns,
        :profile_show_bio,
        :profile_show_email,
        :profile_show_phone,
        :profile_show_member_since,
        :profile_show_sectors,
        :profile_show_affiliations,
        :profile_show_social_media,
        :profile_show_events_registered,
        :profile_show_stories,
        :profile_show_story_ideas,
        :profile_show_workshop_variations,
        :profile_show_workshops,
        :profile_show_workshop_logs,
        :member_since,
        :linked_in_url,
        :facebook_url,
        :instagram_url,
        :youtube_url,
        :twitter_url,
        :created_by_id, :updated_by_id,
        sectorable_items_attributes: [ :id, :sector_id, :is_leader, :_destroy ],
        addresses_attributes: [
          :id,
          :address_type,
          :street_address,
          :city,
          :state,
          :zip_code,
          :country,
          :county,
          :district,
          :locality,
          :phone,
          :_destroy
        ],
        contact_methods_attributes: [
          :id,
          :address_id,
          :contactable_id,
          :contactable_type,
          :contact_type,
          :kind,
          :value,
          :is_primary,
          :inactive,
          :_destroy
        ],
        user_attributes: [
          :id, :facilitator_id,
          :first_name,
          :last_name,
          :email,
          :birthday,
          :inactive,
          :super_user,
          :phone,
          :phone2,
          :phone3,
          :best_time_to_call,
          :address,
          :city,
          :state,
          :zip,
          :address2,
          :city2,
          :state2,
          :zip2,
          :notes,
          project_users_attributes: [
            :id,
            :project_id,
            :position,
            :title,
            :inactive,
            :_destroy
          ]
        ],
      )
    end
end
