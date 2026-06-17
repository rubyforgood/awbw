class AddSlugToFormSubmissions < ActiveRecord::Migration[8.1]
  def up
    add_column :form_submissions, :slug, :string unless column_exists?(:form_submissions, :slug)
    add_index :form_submissions, :slug, unique: true unless index_exists?(:form_submissions, :slug)
  end

  def down
    remove_index :form_submissions, :slug if index_exists?(:form_submissions, :slug)
    remove_column :form_submissions, :slug if column_exists?(:form_submissions, :slug)
  end
end
