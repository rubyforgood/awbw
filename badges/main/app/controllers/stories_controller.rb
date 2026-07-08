class StoriesController < ApplicationController
  include ExternallyRedirectable, AhoyTracking, TagAssignable

  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_story, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    @author = Person.find_by(id: params[:author_id]) if params[:author_id].present?
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 12
      base_scope = authorized_scope(Story.includes(:windows_type, :organization, :workshop,
                                                   :author, :bookmarks, :primary_asset,
                                                   :story_idea, created_by: :person))
      filtered = base_scope.search_by_params(params)
      sortable = %w[title updated_at created_at windows_type workshop author organization]
      @sort = sortable.include?(params[:sort]) ? params[:sort] : "created_at"
      @sort_direction = params[:direction] == "asc" ? "asc" : "desc"
      filtered = apply_sort(filtered, @sort, @sort_direction)
      @stories = filtered.paginate(page: params[:page], per_page: per_page).decorate
      @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"

      render :stories_results
    else
      @organizations = authorized_scope(Organization.all, as: :affiliated).order(:name)
      render :index
    end
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
    @story = Story.new(story_params.except(:category_ids, :sector_ids))
    @story.created_by = current_user
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
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "Story create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @story, notice: "Story was successfully created."
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
      if @story.update(story_params.except(:images, :category_ids, :sector_ids))
        assign_associations(@story)
        if params[:promote_idea_assets] == "true"
          @story.attach_assets_from_idea!
        end
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "Story update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @story, notice: "Story was successfully updated.", status: :see_other
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
    @organizations = authorized_scope(Organization.all, as: :affiliated).order(:name)
    @story_ideas = authorized_scope(StoryIdea.includes(:created_by))
                            .references(:users)
                            .order(:created_at)
    @people = Person.order(Arel.sql("LOWER(first_name), LOWER(last_name)"))
    @windows_types = WindowsType.all
    @workshops = authorized_scope(Workshop.all).includes(:windows_type).order(:title)
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || type.published? }
        .sort_by { |type, _| [ type&.story_specific? ? 0 : 1, type&.name.to_s.downcase ] }
    @sectors = Sector.published.order(:name)
    submitted_sector_ids = Array(params.dig(:story, :sector_ids)).reject(&:blank?)
    submitted_category_ids = Array(params.dig(:story, :category_ids)).reject(&:blank?)
    if submitted_sector_ids.any? || submitted_category_ids.any?
      @preselected_sector_ids = submitted_sector_ids.map(&:to_i)
      @preselected_category_ids = submitted_category_ids.map(&:to_i)
    elsif @story_idea
      @preselected_sector_ids = @story_idea.sector_ids
      @preselected_category_ids = @story_idea.category_ids
    end
    @story.build_primary_asset if @story.primary_asset.blank?
    @story.gallery_assets.build
  end

  private

  def set_story
    # Accepts both the bare id ("23") and the slugged param ("23-my-great-story");
    # ActiveRecord casts the leading id via `to_i`, so both resolve the same story.
    @story = Story.find(params[:id])
  end

  def apply_sort(scope, column, direction)
    dir = direction.to_sym
    case column
    when "title", "updated_at", "created_at"
      scope.reorder(column => dir)
    when "windows_type"
      scope.left_joins(:windows_type)
           .reorder(WindowsType.arel_table[:short_name].public_send(dir))
    when "workshop"
      scope.left_joins(:workshop)
           .reorder(Workshop.arel_table[:title].public_send(dir))
    when "author"
      # Match Story#author_person, which the column renders: sort by the explicit
      # author, falling back to the creating user's person. `created_by: :person`
      # is the second join to `people`, so Rails aliases it `people_users`.
      creator_person = Person.arel_table.alias("people_users")
      author_first_name = Arel::Nodes::NamedFunction.new(
        "COALESCE",
        [ Person.arel_table[:first_name], creator_person[:first_name] ]
      )
      scope.left_joins(:author, created_by: :person)
           .reorder(author_first_name.public_send(dir))
    when "organization"
      scope.left_joins(:organization)
           .reorder(Organization.arel_table[:name].public_send(dir))
    else
      scope.reorder(created_at: :desc)
    end
  end

  # Strong parameters
  def story_params
    params.require(:story).permit(
      :title, :rhino_body, :featured, :published, :publicly_visible, :publicly_featured, :youtube_url, :website_url,
      :windows_type_id, :organization_id, :workshop_id, :external_workshop_title,
      :author_id, :updated_by_id, :story_idea_id, :spotlighted_facilitator_id, :author_credit_preference,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
    )
  end

  def set_story_attributes_from(idea)
    {
      story_idea_id: idea.id,
      rhino_body: idea.rhino_body,
      organization_id: idea.organization.id,
      workshop_id: idea.workshop_id,
      external_workshop_title: idea.external_workshop_title,
      windows_type_id: idea.windows_type_id,
      youtube_url: idea.youtube_url,
      author_id: idea.created_by&.person_id,
      author_credit_preference: idea.author_credit_preference
    }
  end
end
