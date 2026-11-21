class CommentsController < ApplicationController
  include AhoyTracking

  before_action :set_commentable, only: [ :new, :create ]
  before_action :set_comment, only: [ :show, :edit, :update, :destroy ]

  # Global, admin-only index of every comment, with the same search boxes as a
  # person's aggregated feed plus remote person/event filters. The actions below
  # manage a single record's comments.
  def index
    authorize!

    base = Comment.all
    if turbo_frame_request?
      filtered = base.search_by_params(params)
      filtered_count = filtered.count
      @total_count = base.count
      @count_display = count_display(filtered_count, @total_count)
      @comments = filtered.includes(:commentable, created_by: :person, updated_by: :person).newest_first
        .paginate(page: params[:page], per_page: params[:number_of_items_per_page].presence || 25, total_entries: filtered_count)
      FeedRecordPreloader.new(@comments).call
      render :comments_results
    else
      @total_count = base.count
      track_view("comments", { page: "index" })
    end
  end

  def show
    authorize! @comment

    respond_to do |format|
      format.html
      format.turbo_stream if params[:cancel].present?
    end
  end

  def new
    authorize!
    @comment = Comment.new

    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def edit
    authorize! @comment

    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create
    authorize!
    @comment = @commentable.comments.build(comment_params)

    if @comment.save
      if record_section_create?
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to comment_path(@comment), notice: "Comment created successfully." }
        end
      else
        @created_comment = @comment
        setup_aggregated_context if aggregated?
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to after_create_html_path, notice: "Comment created successfully." }
        end
      end
    elsif record_section_create?
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_content }
        format.html { render :new, status: :unprocessable_content }
      end
    else
      redirect_back_or_to root_path, alert: "Failed to create comment."
    end
  end

  def update
    authorize! @comment
    target = commentable_target
    @comment.commentable = target if target

    if @comment.update(comment_params)
      flash.now[:notice] = "Saved"
      setup_aggregated_context

      respond_to do |format|
        format.turbo_stream
        format.html do
          if record_section_update?
            redirect_to comment_path(@comment), status: :see_other
          else
            redirect_back_or_to root_path
          end
        end
      end
    elsif record_section_update?
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_content }
        format.html { render :edit, status: :unprocessable_content }
      end
    else
      setup_aggregated_context
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back_or_to root_path, alert: "Failed to update comment." }
      end
    end
  end

  def destroy
    authorize! @comment
    @comment.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to root_path, notice: "Comment deleted." }
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

  # A create from the record's comments & communications section: the signed
  # sgid names the record, and there is no person-feed context.
  def record_section_create?
    params[:commentable_sgid].present? && !aggregated? && params[:for_person_id].blank?
  end

  # An update from that same record section (inline row or full-page form), not
  # the combined/aggregated feeds or a live toggle.
  def record_section_update?
    params[:combined].blank? && params[:aggregated].blank? && params[:toggle].blank?
  end

  # The combined feed's composer posts a plain (non-stream) comment and names the
  # person via for_person_id, so land back on that person's combined feed. Any
  # other non-stream post falls back to where it came from.
  def after_create_html_path
    if params[:for_person_id].present?
      comments_and_communications_path(person_id: params[:for_person_id])
    else
      request.referer || root_path
    end
  end

  def setup_aggregated_context
    return if params[:for_person_id].blank?
    @aggregator_person = Person.find(params[:for_person_id]).decorate
    @comment_targets = helpers.person_record_targets(@aggregator_person)
  end

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def set_commentable
    # The aggregated composer files against many records, so it submits the
    # chosen record as a signed GlobalID rather than a per-target route. Signed,
    # so the type/id can't be tampered with.
    if params[:commentable_sgid].present?
      @commentable = commentable_target
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

  def commentable_target
    return if params[:commentable_sgid].blank?

    GlobalID::Locator.locate_signed(params[:commentable_sgid])
  end

  def comment_params
    params.require(:comment).permit(:topic, :body, :flagged)
  end
end
