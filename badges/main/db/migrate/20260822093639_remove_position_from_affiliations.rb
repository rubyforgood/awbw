class RemovePositionFromAffiliations < ActiveRecord::Migration[8.1]
  # Vestigial column: the old integer role enum (default: 0, liaison: 1, leader: 2,
  # assistant: 3) was converted to free-text `title` on prod and removed from the
  # model in #432/#735, but the column itself was never dropped.
  def up
    remove_column :affiliations, :position, if_exists: true
  end

  def down
    add_column :affiliations, :position, :integer unless column_exists?(:affiliations, :position)
  end
end
