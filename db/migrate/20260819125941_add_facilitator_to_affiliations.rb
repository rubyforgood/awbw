class AddFacilitatorToAffiliations < ActiveRecord::Migration[8.1]
  # Denormalized cache of "is this the standing Facilitator affiliation?", kept in
  # sync from the title by Affiliation. Replaces the raw BINARY TRIM(title) scope.
  # Schema only — existing rows are backfilled by the affiliations:backfill_facilitator
  # rake task after deploy (see lib/tasks).
  def up
    return if column_exists?(:affiliations, :facilitator)

    add_column :affiliations, :facilitator, :boolean, null: false, default: false
  end

  def down
    remove_column :affiliations, :facilitator, if_exists: true
  end
end
