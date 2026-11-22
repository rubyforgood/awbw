module Comments
  class RecordSectionsController < ApplicationController
    before_action :set_commentable, only: [ :new, :create ]
    before_action :set_comment, only: [ :show, :edit, :update, :destroy ]

    def new
      authorize! Comment
      @comment = Comment.new
    end

    def create
      authorize! Comment
      @comment = @commentable.comments.build(comment_params)

      unless @comment.save
        render :create, status: :unprocessable_content
      end
    end

    def show
      authorize! @comment
    end

    def edit
      authorize! @comment
    end

    def update
      authorize! @comment

      if @comment.update(comment_params)
        flash.now[:notice] = "Saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize! @comment
      @comment.destroy!
    end

    private

    def set_commentable
      @commentable = GlobalID::Locator.locate_signed(params[:commentable_sgid])
      raise ActiveRecord::RecordNotFound unless @commentable
    end

    def set_comment
      @comment = Comment.find(params[:id])
    end

    def comment_params
      params.expect(comment: [ :topic, :body, :flagged ])
    end
  end
end
