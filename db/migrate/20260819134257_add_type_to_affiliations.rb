class AddTypeToAffiliations < ActiveRecord::Migration[8.1]
  # STI discriminator: FacilitatorAffiliation vs JobAffiliation. Affiliation derives
  # the type from the title on save (JobAffiliation is the default for any non-
  # "Facilitator" title). Intentionally nullable with NO column default: a default
  # subclass name would make Affiliation.new instantiate that subclass, so a row
  # the callback then re-types would raise RecordNotFound on reload. Schema only —
  # existing rows are typed by the affiliations:backfill_facilitator rake task
  # after deploy (see lib/tasks); app-created rows always get a type via the callback.
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
