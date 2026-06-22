class CommentsController < ApplicationController
  before_action :set_commentable
  before_action :require_commentable, only: :create

  def index
    authorize!

    respond_to do |format|
      format.html do
        if turbo_frame_request? && @commentable
          @comments = @commentable.comments.newest_first.paginate(page: params[:page], per_page: 10)
          render partial: "comments/list", locals: { commentable: @commentable, comments: @comments }
        else
          @comments = index_comments.paginate(page: params[:page], per_page: 10)
        end
      end
    end
  end

  def create
    authorize!
    @comment = @commentable.comments.build(comment_params)
    @comment.created_by = current_user
    @comment.updated_by = current_user

    if @comment.save
      @comment = @commentable.comments.build
      @comments = @commentable.comments.newest_first.paginate(page: 1, per_page: 10)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path, notice: "Comment created successfully." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("comment_form", partial: "comments/form", locals: { commentable: @commentable }) }
        format.html { redirect_back fallback_location: root_path, alert: "Failed to create comment." }
      end
    end
  end

  private

  # Scoped to a commentable: every comment related to that record (see
  # RelatedComments). Top-level /comments: a preview of every comment in the
  # system alongside the record each is about.
  def index_comments
    return all_comments unless @commentable

    RelatedComments.new(@commentable).comments
  end

  def all_comments
    Comment.includes(:commentable, created_by: :person, updated_by: :person).newest_first
  end

  def set_commentable
    @commentable =
      if params[:person_id]
        Person.find(params[:person_id])
      elsif params[:user_id]
        User.find(params[:user_id])
      elsif params[:organization_id]
        Organization.find(params[:organization_id])
      elsif params[:event_registration_id]
        EventRegistration.find(params[:event_registration_id])
      elsif params[:workshop_id]
        Workshop.find(params[:workshop_id])
      end
  end

  def require_commentable
    redirect_to root_path, alert: "Invalid commentable resource" unless @commentable
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
