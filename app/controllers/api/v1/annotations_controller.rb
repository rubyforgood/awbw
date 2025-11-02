class Api::V1::AnnotationsController < Api::V1::ApiController
  def index
    @bookmark = Bookmark.find(params[:bookmark_id])
    @annotations = @bookmark.bookmark_annotations
    render json: @annotations.map(&:content_with_id).to_json, status: :ok
  end

  def create
    @bookmark = Bookmark.find(params[:bookmark_id])
    @annotation = @bookmark.bookmark_annotations.build(
      annotation: params[:annotation].to_json
    )
    if @annotation.save
      render json: @annotation, status: :ok
    else
      render json: {}, status: :unprocessable_content
    end
  end

  def update
    @annotation = BookmarkAnnotation.find(params[:id])
    if @annotation.update(annotation: params[:annotation])
      render json: @annotation, status: :ok
    else
      render json: {}, status: :unprocessable_content
    end
  end

  def destroy
    @annotation = BookmarkAnnotation.find(params[:id])
    if @annotation
      @annotation.destroy
      render json: @annotation, status: :ok
    else
      render json: {}, status: :unprocessable_content
    end
  end
end
