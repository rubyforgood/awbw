class RenameReferenceUrlToYoutubeUrlOnWorkshopVariation < ActiveRecord::Migration[8.1]
  def change
    rename_column :workshop_variations, :reference_url, :youtube_url
  end
end
