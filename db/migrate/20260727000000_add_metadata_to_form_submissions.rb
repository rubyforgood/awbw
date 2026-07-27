class AddMetadataToFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :form_submissions, :metadata, :json
  end
end
