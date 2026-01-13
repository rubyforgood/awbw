class RichTextAssetMentionsController < ApplicationController
  def index
    # Use your own search logic here, but something like
    # @q = User.ransack({ name_cont: params[:query] })
    # @users = @q.result.distinct.limit(5)
    @rich_text_assets = RichTextAsset.where(id: params[:query])

    respond_to do |format|
      format.json
    end
  end
end
