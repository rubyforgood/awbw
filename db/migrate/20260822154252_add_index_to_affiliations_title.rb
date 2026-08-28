class AddIndexToAffiliationsTitle < ActiveRecord::Migration[8.1]
  # The .facilitators scope filters on the title. A plain index is usable because
  # the scope matches the bare column (`title = BINARY ?`) rather than wrapping it
  # in TRIM — titles are normalized on write, so no function is needed in the query.
  def up
    add_index :affiliations, :title unless index_exists?(:affiliations, :title)
  end

  def down
    remove_index :affiliations, :title, if_exists: true
  end
end
