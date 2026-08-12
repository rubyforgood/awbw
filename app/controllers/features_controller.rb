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

  # Admin-only "Sync latest updates" button: add any newly-shipped features from
  # config/features.yml and fill in blank fields on existing ones (never
  # overwrites details an admin has already filled in).
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
