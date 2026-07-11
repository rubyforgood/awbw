class RichTextAssetMentionsController < ApplicationController
  skip_verify_authorized
  def index
    # authorize!
    record = Draper.undecorate(GlobalID::Locator.locate_signed(params[:sgid]))

    unless record.respond_to?(:rich_text_assets)
      render json: [] and return
    end

    @rich_text_assets = record.rich_text_assets.where(id: params[:query])


    respond_to do |format|
      format.json
    end
  end
end
