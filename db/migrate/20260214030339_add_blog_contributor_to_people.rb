class AddBlogContributorToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :blog_contributor, :boolean, default: false, null: false
  end
end
