class CommentsController < ApplicationController
  before_action :set_commentable

  def index
    authorize!
    @comments = @commentable.comments.newest_first.paginate(page: params[:page], per_page: 10)

    respond_to do |format|
      format.html { render partial: "comments/list", locals: { commentable: @commentable, comments: @comments } }
    end
  end

  def create
    authorize!
    @comment = @commentable.comments.build(comment_params)

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

  def set_commentable
    if params[:person_id]
      @commentable = Person.find(params[:person_id])
    elsif params[:user_id]
      @commentable = User.find(params[:user_id])
    elsif params[:organization_id]
      @commentable = Organization.find(params[:organization_id])
    elsif params[:event_registration_id]
      @commentable = EventRegistration.find(params[:event_registration_id])
    else
      redirect_to root_path, alert: "Invalid commentable resource"
    end
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
