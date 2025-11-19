class AddWebsiteUrlToStory < ActiveRecord::Migration[8.1]
  def change
    add_column :stories, :website_url, :string
  end
end
