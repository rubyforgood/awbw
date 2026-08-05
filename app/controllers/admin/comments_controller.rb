module Admin
  # Global, admin-only index of every comment in the system, with the same search
  # boxes as a person's aggregated feed plus remote person/event filters. Distinct
  # from the nested CommentsController, which manages one record's comments.
  class CommentsController < ApplicationController
    include AhoyTracking

    def index
      authorize! Comment, to: :index?, with: CommentPolicy

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
  end
end
