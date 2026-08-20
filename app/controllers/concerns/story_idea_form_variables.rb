module StoryIdeaFormVariables
  extend ActiveSupport::Concern

  # Shared by StoryIdeasController (new/edit) and StorySharesController (share) so
  # the public "Share your story" page renders the same form as the admin one.
  def set_story_idea_form_variables
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @organizations = (@user || current_user)&.organizations&.order(:name) || Organization.none
    @windows_types = WindowsType.all

    users = authorized_scope(User.has_access.includes(:person))
    users = users.or(User.where(id: @story_idea.created_by_id)) if @story_idea&.created_by_id
    @users = users.distinct.order("people.first_name, people.last_name")

    @story_population_type = CategoryType.find_by(name: "StoryPopulation")
    @story_population_categories = @story_population_type&.categories&.published&.ordered_by_position_and_name || []
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
end
