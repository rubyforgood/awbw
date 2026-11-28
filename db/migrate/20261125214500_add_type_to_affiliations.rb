class AddTypeToAffiliations < ActiveRecord::Migration[8.1]
  def up
    add_column :affiliations, :type, :string
    add_index :affiliations, :type

    execute <<~SQL
      UPDATE affiliations
      SET type = 'facilitator', title = NULL
      WHERE title = BINARY 'Facilitator'
    SQL
    execute "UPDATE affiliations SET type = 'job' WHERE type IS NULL"
    change_column_null :affiliations, :type, false
  end

  def down
    execute "UPDATE affiliations SET title = 'Facilitator' WHERE type = 'facilitator'"
    remove_index :affiliations, :type
    remove_column :affiliations, :type
  end
end
