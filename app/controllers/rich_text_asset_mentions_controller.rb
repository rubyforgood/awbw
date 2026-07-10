class RichTextAssetMentionsController < ApplicationController
  skip_verify_authorized
  def index
    # authorize!
    record = GlobalID::Locator.locate_signed(params[:sgid])
    record = record.object if record.respond_to?(:decorated?) && record.decorated?

    unless record.respond_to?(:rich_text_assets)
      render json: [] and return
    end

    @rich_text_assets = record.rich_text_assets.where(id: params[:query])


    respond_to do |format|
      format.json
    end
  end
end
