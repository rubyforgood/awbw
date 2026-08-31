class RemoveUnusedLegacyColumns < ActiveRecord::Migration[7.2]
  # Dead + soft-referenced `legacy`/`legacy_id` columns left over from the pre-portal
  # import (rubyforgood/awbw#400). HOLD UNTIL AFTER the FileMaker prod-data import:
  # the `legacy_id` columns map old FileMaker records during import, so they must
  # survive until that finishes. Load-bearing legacy columns are intentionally kept:
  # resources.legacy_author_name, workshops.legacy, workshop_variations.legacy,
  # windows_types.legacy_id.
  COLUMNS = {
    categories: [ [ :legacy_id, :integer ] ],
    categorizable_items: [ [ :legacy_id, :integer ] ],
    category_types: [ [ :legacy_id, :string ] ],
    organizations: [ [ :legacy, :boolean, { default: false } ], [ :legacy_id, :integer ] ],
    permissions: [ [ :legacy_id, :integer ] ],
    quotable_item_quotes: [ [ :legacy_id, :integer ] ],
    quotes: [ [ :legacy, :boolean, { default: false } ], [ :legacy_id, :integer ] ],
    resources: [ [ :legacy, :boolean ], [ :legacy_id, :integer ] ],
    users: [ [ :legacy, :boolean, { default: false } ], [ :legacy_id, :integer ] ],
    workshops: [ [ :legacy_id, :integer ] ]
  }.freeze

  def up
    COLUMNS.each do |table, columns|
      columns.each do |name, _type, _opts|
        remove_column table, name, if_exists: true
      end
    end
  end

  def down
    COLUMNS.each do |table, columns|
      columns.each do |name, type, opts|
        add_column table, name, type, **(opts || {}) unless column_exists?(table, name)
      end
    end
  end
end
