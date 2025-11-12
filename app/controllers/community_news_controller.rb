class CommunityNewsController < ApplicationController
  before_action :set_community_news, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = CommunityNews.all
    @community_news_count = unpaginated.count
    @community_news = unpaginated.paginate(page: params[:page], per_page: per_page)
  end

  def show
  end

  def new
    @community_news = CommunityNews.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @community_news = CommunityNews.new(community_news_params)

    if @community_news.save
      redirect_to community_news_index_path, notice: "Community news was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @community_news.update(community_news_params)
      redirect_to community_news_index_path, notice: "Community news was successfully updated.", status: :see_other
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
  end

  private

  def set_community_news
    @community_news = CommunityNews.find(params[:id])
  end

  # Strong parameters
  def community_news_params
    params.require(:community_news).permit(
      :title, :body, :published, :featured,
      :reference_url,:youtube_url,
      :project_id, :windows_type_id,
      :author_id, :created_by_id, :updated_by_id
    )
  end
end
