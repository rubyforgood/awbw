class AddTypeToAffiliations < ActiveRecord::Migration[8.1]
  # STI discriminator. Nullable with NO default on purpose: a default subclass name
  # makes Affiliation.new build that subclass, so a row the callback re-types raises
  # RecordNotFound on reload. Existing rows are typed post-deploy by
  # affiliations:backfill_facilitator (see lib/tasks); new rows via the model callback.
  def up
    return if column_exists?(:affiliations, :type)

    add_column :affiliations, :type, :string
    add_index :affiliations, :type
  end

  def down
    remove_index :affiliations, :type, if_exists: true
    remove_column :affiliations, :type, if_exists: true
  end
end
