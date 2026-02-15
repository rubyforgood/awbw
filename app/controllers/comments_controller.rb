class CommentsController < ApplicationController
  before_action :set_commentable

  def index
    @comments = @commentable.comments.paginate(page: params[:page], per_page: 10)

    respond_to do |format|
      format.html { render partial: "comments/list", locals: { commentable: @commentable, comments: @comments } }
    end
  end

  def create
    @comment = @commentable.comments.build(comment_params)

    if @comment.save
      @comments = @commentable.comments.paginate(page: 1, per_page: 10)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path, notice: "Comment created successfully." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("comment_form", partial: "comments/form", locals: { commentable: @commentable, comment: @comment }) }
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
    end
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
