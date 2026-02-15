class CommunityNewsController < ApplicationController
  include ExternallyRedirectable, AhoyTracking
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_community_news, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 12
      base_scope = authorized_scope(CommunityNews.includes([ :bookmarks, :primary_asset,
                                                             :author, :organization, author: :person ]))
      filtered = base_scope.search_by_params(params)
      @community_news = filtered.paginate(page: params[:page], per_page: per_page).decorate
      @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"

      render :index_lazy
    else
      render :index
    end
  end

  def show
    @community_news = @community_news.decorate
    authorize! @community_news
    track_view(@community_news)

    if @community_news.external_url.present?
      redirect_to_external @community_news.link_target
      nil
    end
  end

  def new
    @community_news = CommunityNews.new.decorate
    authorize! @community_news
    set_form_variables
  end

  def edit
    @community_news = @community_news.decorate
    authorize! @community_news
    set_form_variables
    if turbo_frame_request?
      render :editor_lazy
    else
      render :edit
    end
  end

  def create
    @community_news = CommunityNews.new(community_news_params)
    authorize! @community_news

    success = false

    CommunityNews.transaction do
      if @community_news.save
        assign_associations(@community_news)
        if params.dig(:library_asset, :new_assets).present?
          update_asset_owner(@community_news)
        end
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Community news create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to community_news_index_path,
                  notice: "Community news was successfully created."
    else
      @community_news = @community_news.decorate
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @community_news
    success = false

    CommunityNews.transaction do
      if @community_news.update(community_news_params)
        assign_associations(@community_news)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Community news update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to community_news_index_path,
                  notice: "Community news was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @community_news
    @community_news.destroy!
    redirect_to community_news_index_path, notice: "Community news was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @organizations = authorized_scope(Organization.all).pluck(:name, :id).sort_by(&:first)
    @authors = authorized_scope(User.has_access.or(User.where(id: @community_news.author_id)))
                   .includes(:person)
                   .map { |u| [ u.full_name, u.id ] }.sort_by(&:first)
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || type.published? }
        .sort_by { |type, _| type&.name.to_s.downcase }
    @sectors = Sector.published.order(:name)
    @community_news.build_primary_asset if @community_news.primary_asset.blank?
    @community_news.gallery_assets.build
  end

  def assign_associations(community_news)
    selected_category_ids = Array(params[:community_news][:category_ids]).reject(&:blank?).map(&:to_i)
    community_news.categories = Category.where(id: selected_category_ids)

    selected_sector_ids = Array(params[:community_news][:sector_ids]).reject(&:blank?).map(&:to_i)
    community_news.sectors = Sector.where(id: selected_sector_ids)
    community_news.save!
  end

  private

  def set_community_news
    @community_news = CommunityNews.find(params[:id])
  end

  # Strong parameters
  def community_news_params
    params.require(:community_news).permit(
      :title, :rhino_body, :published, :featured, :publicly_visible, :publicly_featured,
      :reference_url, :youtube_url,
      :organization_id,
      :author_id, :created_by_id, :updated_by_id,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ]
    )
  end
end
