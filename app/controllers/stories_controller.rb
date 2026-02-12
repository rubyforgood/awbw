class StoriesController < ApplicationController
  include ExternallyRedirectable, AhoyTracking

  skip_before_action :authenticate_user!, only: [ :index, :show, :show_share_portal ]
  before_action :set_story, only: [ :show, :show_share_portal, :edit, :update, :destroy ]

  def index
    authorize!
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 12
      base_scope = authorized_scope(Story.includes(:windows_type, :organization, :workshop,
                                                   :created_by, :bookmarks, :primary_asset,
                                                   :story_idea))
      filtered = base_scope.search_by_params(params)
                           .order(created_at: :desc)
      @stories = filtered.paginate(page: params[:page], per_page: per_page).decorate
      @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"

      render :index_lazy
    else
      render :index
    end
  end

  def share_portal
    authorize!
    per_page = params[:number_of_items_per_page].presence || 12
    base_scope = authorized_scope(Story.includes(:windows_type, :organization, :workshop, :created_by, :bookmarks, :primary_asset))
    filtered = base_scope.search_by_params(params)
                         .order(created_at: :desc)
    @stories = filtered.paginate(page: params[:page], per_page: per_page).decorate

    @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"

    @featured_story = Story.first
    sector_names = [
      "Domestic Violence",
      "Social Justice",
      "Facilitator Spotlights"
    ]

    @stories_by_focus =
      sector_names.index_with do |focus|
        matching = @stories.select do |story|
          story.respond_to?(:sector_names_all) &&
            story.sector_names_all.include?(focus)
        end

        remaining_needed = 5 - matching.size
        if remaining_needed > 0
          filler = @stories.reject { |story| matching.include?(story) }
                           .first(remaining_needed)
          matching + filler
        else
          matching.first(5)
        end
      end
    @popular_stories = @stories.sort_by { |s| s.bookmarks.size }.reverse.first(6)

    render layout: "share_portal"
  end

  def show
    @story = @story.decorate
    authorize! @story
    track_view(@story)

    if @story.external_url.present? && !params[:no_redirect].present?
      redirect_to_external @story.link_target
      nil
    end
  end

  def show_share_portal
    @story = @story.decorate
    authorize! @story
    track_view(@story)

    # Fetch related stories for "What Others Are Reading" section
    base_scope = authorized_scope(Story.includes(:bookmarks, :primary_asset))
    @popular_stories = base_scope.where.not(id: @story.id)
                                 .order(Arel.sql("(SELECT COUNT(*) FROM bookmarks WHERE bookmarks.resource_id = stories.id AND bookmarks.resource_type = 'Story') DESC, created_at DESC"))
                                 .limit(4)
                                 .decorate

    render layout: "share_portal"
  end

  def new
    if params[:story_idea_id].present?
      @story_idea = StoryIdea.find(params[:story_idea_id])
      @story = Story.new(set_story_attributes_from(@story_idea))
    else
      @story = Story.new
    end
    authorize! @story
    @story.decorate
    set_form_variables
  end

  def edit
    @story = @story.decorate
    authorize! @story
    set_form_variables
    if turbo_frame_request?
      render :editor_lazy
    else
      render :edit
    end
  end

  def create
    @story = Story.new(story_params)
    authorize! @story

    success = false

    Story.transaction do
      if @story.save
        assign_associations(@story)
        if params[:promote_idea_assets] == "true"
          @story.attach_assets_from_idea!
        elsif params.dig(:library_asset, :new_assets).present?
          update_asset_owner(@story)
        end
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Story create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to stories_path, notice: "Story was successfully created."
    else
      @story = @story.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @story
    success = false

    Story.transaction do
      if @story.update(story_params)
        assign_associations(@story)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Story update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to stories_path, notice: "Story was successfully updated.", status: :see_other
    else
      @story = @story.decorate
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @story
    @story.destroy!
    redirect_to stories_path, notice: "Story was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @story_idea = StoryIdea.find(params[:story_idea_id]) if params[:story_idea_id].present?
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @organizations = (@user || current_user).organizations.order(:name)
    @story_ideas = StoryIdea.includes(:created_by)
                            .references(:users)
                            .order(:created_at)
    @windows_types = WindowsType.all
    @workshops = Workshop.all.order(:title)
    @users = User.active.or(User.where(id: @story.created_by_id))
                 .includes(:person)
                 .order("people.first_name, people.last_name")
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || type.published? }
        .sort_by { |type, _| type&.name.to_s.downcase }
    @sectors = Sector.published.order(:name)
    @story.build_primary_asset if @story.primary_asset.blank?
    @story.gallery_assets.build
  end

  def assign_associations(story)
    selected_category_ids = Array(params[:story][:category_ids]).reject(&:blank?).map(&:to_i)
    story.categories = Category.where(id: selected_category_ids)

    selected_sector_ids = Array(params[:story][:sector_ids]).reject(&:blank?).map(&:to_i)
    story.sectors = Sector.where(id: selected_sector_ids)
    story.save!
  end


  private

  def set_story
    @story = Story.find(params[:id])
  end

  # Strong parameters
  def story_params
    params.require(:story).permit(
      :title, :rhino_body, :featured, :published, :publicly_visible, :publicly_featured, :youtube_url, :website_url,
      :windows_type_id, :organization_id, :workshop_id, :external_workshop_title,
      :created_by_id, :updated_by_id, :story_idea_id, :spotlighted_facilitator_id,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ]
    )
  end

  def set_story_attributes_from(idea)
    {
      rhino_body: idea.body,
      organization_id: idea.organization.id,
      workshop_id: idea.workshop_id,
      external_workshop_title: idea.external_workshop_title,
      windows_type_id: idea.windows_type_id,
      youtube_url: idea.youtube_url
    }
  end
end
