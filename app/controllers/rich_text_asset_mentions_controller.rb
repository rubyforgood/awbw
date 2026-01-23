class RichTextAssetMentionsController < ApplicationController
  def index
    record = GlobalID::Locator.locate_signed(params[:sgid])

    unless record
      render json: [] and return
    end

    @rich_text_assets = record.rich_text_assets.where(id: params[:query])


    respond_to do |format|
      format.json
    end
  end
end
