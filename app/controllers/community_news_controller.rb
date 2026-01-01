class CommunityNewsController < ApplicationController
  include ExternallyRedirectable
  before_action :set_community_news, only: [ :show, :edit, :update, :destroy ]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unfiltered = current_user.super_user? ? CommunityNews.all : Community_news.published
    filtered = unfiltered.search_by_params(params)
    @community_news = filtered.paginate(page: params[:page], per_page: per_page).decorate

    @count_display = if filtered.count == unfiltered.count
                       unfiltered.count
    else
                       "#{filtered.count}/#{unfiltered.count}"
    end
  end

  def show
    @community_news = @community_news.decorate
    @community_news.increment_view_count!(session: session, request: request)

    if @community_news.external_url.present?
      redirect_to_external @community_news.link_target
      nil
    end
  end

  def new
    @community_news = CommunityNews.new.decorate
    set_form_variables
  end

  def edit
    @community_news = @community_news.decorate
    set_form_variables
  end

  def create
    @community_news = CommunityNews.new(community_news_params)

    if @community_news.save
      redirect_to community_news_index_path,
                  notice: "Community news was successfully created."
    else
      @community_news = @community_news.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @community_news.update(community_news_params)
      redirect_to community_news_index_path,
                  notice: "Community news was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @community_news.destroy!
    redirect_to community_news_index_path, notice: "Community news was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @community_news.build_primary_asset if @community_news.primary_asset.blank?
    @community_news.gallery_assets.build

    @organizations = Project.pluck(:name, :id).sort_by(&:first)
    @windows_types = WindowsType.all
    @authors = User.active.or(User.where(id: @community_news.author_id))
                   .map { |u| [ u.full_name, u.id ] }.sort_by(&:first)
  end

  private

  def set_community_news
    @community_news = CommunityNews.find(params[:id])
  end

  # Strong parameters
  def community_news_params
    params.require(:community_news).permit(
      :title, :body, :published, :featured,
      :reference_url, :youtube_url,
      :project_id, :windows_type_id,
      :author_id, :created_by_id, :updated_by_id,
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ]
    )
  end
end
