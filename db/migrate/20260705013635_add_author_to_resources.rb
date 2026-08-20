class AddAuthorToResources < ActiveRecord::Migration[8.1]
  def up
    # Preserve the old free-text author string as a legacy field; the new
    # author is a Person reference, mirroring stories and workshop variations.
    rename_column :resources, :author, :legacy_author_name if column_exists?(:resources, :author)
    add_reference :resources, :author, foreign_key: { to_table: :people }, index: true, null: true unless column_exists?(:resources, :author_id)
    add_column :resources, :author_credit_preference, :string unless column_exists?(:resources, :author_credit_preference)
  end

  def down
    remove_column :resources, :author_credit_preference, if_exists: true
    remove_reference :resources, :author, foreign_key: { to_table: :people }, if_exists: true
    rename_column :resources, :legacy_author_name, :author if column_exists?(:resources, :legacy_author_name)
  end
end
