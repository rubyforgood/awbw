class TopicSubscriptionTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_topic_subscription_type, only: [ :edit, :update, :destroy, :archive, :unarchive ]

  def index
    authorize! TopicSubscriptionType
    @active_count = TopicSubscriptionType.active.count
    @archived_count = TopicSubscriptionType.archived.count
    @status_filter = params[:status] == "archived" ? "archived" : "active"

    scope = @status_filter == "archived" ? TopicSubscriptionType.archived : TopicSubscriptionType.active
    @topic_subscription_types = scope.ordered
  end

  def new
    authorize! TopicSubscriptionType
    @topic_subscription_type = TopicSubscriptionType.new
  end

  def create
    authorize! TopicSubscriptionType
    @topic_subscription_type = TopicSubscriptionType.new(topic_subscription_type_params)
    @topic_subscription_type.created_by = current_user
    @topic_subscription_type.updated_by = current_user

    if @topic_subscription_type.save
      redirect_to topic_subscription_types_path, notice: "Topic added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @topic_subscription_type
  end

  def update
    authorize! @topic_subscription_type
    @topic_subscription_type.updated_by = current_user

    if @topic_subscription_type.update(topic_subscription_type_params)
      redirect_to topic_subscription_types_path, notice: "Topic updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def archive
    authorize! @topic_subscription_type, to: :update?
    @topic_subscription_type.archive!
    redirect_to topic_subscription_types_path, notice: "Topic archived."
  end

  def unarchive
    authorize! @topic_subscription_type, to: :update?
    @topic_subscription_type.unarchive!
    redirect_to topic_subscription_types_path, notice: "Topic restored."
  end

  def destroy
    authorize! @topic_subscription_type
    if @topic_subscription_type.destroy
      redirect_to topic_subscription_types_path, notice: "Topic deleted."
    else
      redirect_to topic_subscription_types_path,
        alert: "Can't delete a topic that has subscriptions — archive it instead."
    end
  end

  private

  def set_topic_subscription_type
    @topic_subscription_type = TopicSubscriptionType.find(params[:id])
  end

  def topic_subscription_type_params
    params.require(:topic_subscription_type).permit(:name, :description, :event_selector)
  end
end
