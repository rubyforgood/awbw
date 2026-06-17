class AddSlugToFormSubmissions < ActiveRecord::Migration[8.1]
  def up
    add_column :form_submissions, :slug, :string unless column_exists?(:form_submissions, :slug)
    add_index :form_submissions, :slug, unique: true unless index_exists?(:form_submissions, :slug)

    # Backfill slugs for existing bulk payment submissions so their public ticket
    # URLs resolve. Other submission roles are reached by id and stay slug-less.
    FormSubmission.reset_column_information
    FormSubmission.where(role: "bulk_payment", slug: nil).find_each do |submission|
      submission.update_column(:slug, FormSubmission.generate_unique_slug)
    end
  end

  def down
    remove_index :form_submissions, :slug if index_exists?(:form_submissions, :slug)
    remove_column :form_submissions, :slug if column_exists?(:form_submissions, :slug)
  end
end
