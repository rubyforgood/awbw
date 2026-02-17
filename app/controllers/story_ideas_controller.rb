class StoryIdeasController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_story_idea, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(StoryIdea.includes(:windows_type, :organization, :workshop, :created_by, :updated_by))
    filtered = base_scope.search_by_params(params)
    @story_ideas = filtered.order(created_at: :desc)
                           .paginate(page: params[:page], per_page: per_page)
                           .decorate
    @story_ideas_count = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"
  end

  def show
    authorize! @story_idea
  end

  def new
    @story_idea = StoryIdea.new
    authorize! @story_idea

    set_form_variables
  end

  def edit
    authorize! @story_idea

    set_form_variables
  end

  def create
    @story_idea = StoryIdea.new(story_idea_params.except(:category_ids, :sector_ids))
    @story_idea.created_by = current_user
    @story_idea.updated_by = current_user
    authorize! @story_idea

    success = false

    StoryIdea.transaction do
      if @story_idea.save
        assign_associations(@story_idea)
        NotificationServices::CreateNotification.call(
          noticeable: @story_idea,
          kind: :idea_submitted_fyi,
          recipient_role: :admin,
          recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
          notification_type: 0)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "StoryIdea create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      flash[:notice] = "StoryIdea was successfully created."
      if allowed_to?(:index?, StoryIdea)
        redirect_to story_ideas_path
      else
        redirect_to root_path
      end
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    @story_idea.updated_by = current_user
    authorize! @story_idea

    success = false

    StoryIdea.transaction do
      if @story_idea.update(story_idea_params.except(:images, :category_ids, :sector_ids))
        assign_associations(@story_idea)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "StoryIdea update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      flash[:notice] = "StoryIdea was successfully updated."
      if allowed_to?(:index?, StoryIdea)
        redirect_to story_ideas_path, status: :see_other
      else
        redirect_to root_path, status: :see_other
      end
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @story_idea

    @story_idea.destroy!
    redirect_to story_ideas_path, notice: "StoryIdea was successfully destroyed."
  end

  # ---------------------------------------------------------

  def set_form_variables
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @organizations = (@user || current_user)&.organizations&.order(:name) || Organization.none
    @windows_types = WindowsType.all

    @workshops = authorized_scope(Workshop.all).includes(:windows_type).order(:title)

    users = authorized_scope(User.has_access.includes(:person))
    users = users.or(User.where(id: @story_idea.created_by_id)) if @story_idea&.created_by_id
    @users = users.distinct.order("people.first_name, people.last_name")

    @story_population_type = CategoryType.find_by(name: "StoryPopulation")
    @story_population_categories = @story_population_type&.categories&.published&.order(:name) || []
    @sectors = Sector.published.order(:name)
    submitted_sector_ids = Array(params.dig(:story_idea, :sector_ids)).reject(&:blank?)
    submitted_category_ids = Array(params.dig(:story_idea, :category_ids)).reject(&:blank?)
    if submitted_sector_ids.any? || submitted_category_ids.any?
      @preselected_sector_ids = submitted_sector_ids.map(&:to_i)
      @preselected_category_ids = submitted_category_ids.map(&:to_i)
    end

    if @story_idea.persisted?
      @categories_grouped =
        Category
          .includes(:category_type)
          .published
          .order(:position, :name)
          .group_by(&:category_type)
          .select { |type, _| type.nil? || type.published? }
          .sort_by { |type, _| [ type&.story_specific? ? 0 : 1, type&.name.to_s.downcase ] }
    end
    @story_idea.build_primary_asset if @story_idea.primary_asset.blank?
    @story_idea.gallery_assets.build
  end

  def assign_associations(story_idea)
    selected_category_ids = Array(params[:story_idea][:category_ids]).reject(&:blank?).map(&:to_i)
    story_idea.categories = Category.where(id: selected_category_ids)

    selected_sector_ids = Array(params[:story_idea][:sector_ids]).reject(&:blank?).map(&:to_i)
    story_idea.sectors = Sector.where(id: selected_sector_ids)
    story_idea.save!
  end

  private

  def set_story_idea
    @story_idea = StoryIdea.find(params[:id])
  end

  def story_idea_params
    params.require(:story_idea).permit(
      :title, :body, :youtube_url,
      :permission_given, :publish_preferences, :promoted_to_story,
      :windows_type_id, :organization_id, :workshop_id, :external_workshop_title,
      :created_by_id, :updated_by_id,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ]
    )
  end
end
