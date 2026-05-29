class AddAnalyticsSnippetsToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :ga4_snippet, :text
    add_column :events, :gtm_head_snippet, :text
    add_column :events, :gtm_body_snippet, :text
  end
end
