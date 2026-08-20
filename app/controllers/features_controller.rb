class FeaturesController < ApplicationController
  before_action :set_feature, only: %i[ show edit update destroy ]

  def index
    authorize! Feature
    scope = authorized_scope(Feature.all)
    @total = scope.count

    if turbo_frame_request?
      @features = filtered_features(scope).decorate
      render :features_results
    else
      present_areas = scope.distinct.pluck(:area)
      present_statuses = scope.distinct.pluck(:display_status)
      @areas = Feature::AREAS.select { |area| present_areas.include?(area[:key]) }
      @statuses = Feature::DISPLAY_STATUSES.slice(*present_statuses)
    end
  end

  def show
    authorize! @feature
    @feature = @feature.decorate
  end

  def new
    @feature = Feature.new(display_status: "user_facing", released_on: Date.current)
    authorize! @feature
  end

  def edit
    authorize! @feature
  end

  def create
    @feature = Feature.new(feature_params)
    authorize! @feature

    if @feature.save
      redirect_to @feature, notice: "Feature was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @feature

    if @feature.update(feature_params)
      redirect_to @feature, notice: "Feature was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @feature
    @feature.destroy!
    redirect_to features_path, notice: "Feature was successfully deleted.", status: :see_other
  end

  def import
    authorize! Feature, to: :create?
    result = FeatureCatalog.new.import!

    notice = if result.any?
      parts = []
      parts << "added #{result.created}" if result.created.positive?
      parts << "filled in #{result.updated}" if result.updated.positive?
      "Latest updates synced — #{parts.join(', ')} #{'feature'.pluralize(result.total)}."
    else
      "You're all caught up — no new updates."
    end
    redirect_to features_path, notice: notice
  end

  private

  def filtered_features(scope)
    scope = scope.where(area: params[:area]) if params[:area].present?
    scope = scope.where(display_status: params[:display_status]) if params[:display_status].present?

    if params[:query].present?
      q = "%#{Feature.sanitize_sql_like(params[:query].strip)}%"
      scope = scope.where("features.name LIKE :q OR features.summary LIKE :q OR features.pro_tips LIKE :q", q: q)
    end

    scope = scope.where(released_on: params[:released_from]..) if params[:released_from].present?
    scope = scope.where(released_on: ..params[:released_to]) if params[:released_to].present?

    direction = params[:direction] == "asc" ? :asc : :desc
    scope.order(released_on: direction, name: :asc)
  end

  def set_feature
    @feature = Feature.find(params[:id])
  end

  def feature_params
    params.require(:feature).permit(
      :name, :area, :display_status, :summary, :pro_tips,
      :external_url, :action_path, :pr_number, :released_on, :published, :rhino_description
    )
  end
end
