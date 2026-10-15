class AddUniqueNameIndexToOrganizations < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_organizations_on_name"

  def up
    duplicates = select_rows(<<~SQL)
      SELECT MIN(name), GROUP_CONCAT(id ORDER BY id) AS organization_ids
      FROM organizations
      WHERE name IS NOT NULL
      GROUP BY name
      HAVING COUNT(*) > 1
    SQL

    if duplicates.any?
      groups = duplicates.map { |name, ids| "#{name} (organizations #{ids})" }
      raise ActiveRecord::MigrationError,
        "Merge these duplicate organizations at /organizations/dedupe_index before adding #{INDEX_NAME}:\n  #{groups.join("\n  ")}"
    end

    add_index :organizations, :name, unique: true, name: INDEX_NAME
  end

  def down
    remove_index :organizations, name: INDEX_NAME, if_exists: true
  end
end
