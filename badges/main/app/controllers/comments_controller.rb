class CommentsController < ApplicationController
  include AhoyTracking

  before_action :set_commentable, except: :index

  # Global, admin-only index of every comment, with the same search boxes as a
  # person's aggregated feed plus remote person/event filters. The nested
  # create/update actions below manage a single record's comments.
  def index
    authorize!

    base = Comment.all
    if turbo_frame_request?
      filtered = base.search_by_params(params).includes(:commentable, :created_by, :updated_by).newest_first
      @total_count = base.count
      @count_display = filtered.count == @total_count ? @total_count : "#{filtered.count}/#{@total_count}"
      @comments = filtered.paginate(page: params[:page], per_page: 25)
      render :comments_results
    else
      @total_count = base.count
      track_view("comments", { page: "index" })
    end
  end

  def create
    authorize!
    @comment = @commentable.comments.build(comment_params)
    @comment.created_by = current_user
    @comment.updated_by = current_user

    if @comment.save
      @created_comment = @comment
      setup_aggregated_context if aggregated?
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path, notice: "Comment created successfully." }
      end
    else
      redirect_back fallback_location: root_path, alert: "Failed to create comment."
    end
  end

  def update
    @comment = @commentable.comments.find(params[:id])
    authorize! @comment
    @comment.updated_by = current_user
    @comment.update(comment_params)
    setup_aggregated_context if aggregated?

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  # The aggregated person-comments page posts from a composer that spans many
  # commentables, so it flags itself and names the person whose feed to refresh.
  # `for_person_id` (not `person_id`) is used deliberately so set_commentable
  # still resolves the real commentable from the route rather than the person.
  def aggregated?
    params[:aggregated].present?
  end

  def setup_aggregated_context
    return if params[:for_person_id].blank?
    @aggregator_person = Person.find(params[:for_person_id]).decorate
    @comment_targets = helpers.person_comment_targets(@aggregator_person)
  end

  def set_commentable
    # The aggregated composer files against many records, so it submits the
    # chosen record as a signed GlobalID rather than a per-target route. Signed,
    # so the type/id can't be tampered with.
    if params[:commentable_sgid].present?
      @commentable = GlobalID::Locator.locate_signed(params[:commentable_sgid])
      redirect_to(root_path, alert: "Invalid commentable resource") unless @commentable
    elsif params[:person_id]
      @commentable = Person.find(params[:person_id])
    elsif params[:user_id]
      @commentable = User.find(params[:user_id])
    elsif params[:organization_id]
      @commentable = Organization.find(params[:organization_id])
    elsif params[:event_registration_id]
      @commentable = EventRegistration.find(params[:event_registration_id])
    elsif params[:scholarship_id]
      @commentable = Scholarship.find(params[:scholarship_id])
    elsif params[:continuing_education_registration_id]
      @commentable = ContinuingEducationRegistration.find(params[:continuing_education_registration_id])
    elsif params[:topic_subscription_id]
      @commentable = TopicSubscription.find(params[:topic_subscription_id])
    elsif params[:workshop_id]
      @commentable = Workshop.find(params[:workshop_id])
    else
      redirect_to root_path, alert: "Invalid commentable resource"
    end
  end

  def comment_params
    params.require(:comment).permit(:topic, :body, :flagged)
  end
end
