class FeaturesController < ApplicationController
  before_action :set_feature, only: %i[ show edit update destroy ]

  def index
    authorize! Feature
    @features = authorized_scope(Feature.all).by_release.decorate
    # Only offer filter options the viewer can actually see something under.
    present_areas = @features.map(&:area).uniq
    present_statuses = @features.map(&:display_status).uniq
    @areas = Feature::AREAS.select { |area| present_areas.include?(area[:key]) }
    @statuses = Feature::DISPLAY_STATUSES.slice(*present_statuses)
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

  # Admin-only "Import from seed" button: pull any features from config/features.yml
  # not already in the database (never overwrites existing ones).
  def import
    authorize! Feature, to: :create?
    created = FeatureCatalog.new.import!
    notice = created.zero? ? "All seed features are already imported." : "Imported #{created} #{'feature'.pluralize(created)} from the seed file."
    redirect_to features_path, notice: notice
  end

  private

  def set_feature
    @feature = Feature.find(params[:id])
  end

  def feature_params
    params.require(:feature).permit(
      :name, :area, :display_status, :summary, :pro_tips,
      :external_url, :released_on, :published, :rhino_description
    )
  end
end
