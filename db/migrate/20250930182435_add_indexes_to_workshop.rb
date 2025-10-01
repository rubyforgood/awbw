class AddIndexesToWorkshop < ActiveRecord::Migration[8.1]
  def up
    # Workshops table
    add_index :workshops, :led_count, if_not_exists: true
    add_index :workshops, [:year, :month], if_not_exists: true
    add_index :workshops, :created_at, if_not_exists: true

    # Handle multiple indexes on title safely
    unless index_exists?(:workshops, :title, name: 'index_workshops_on_title')
      add_index :workshops, :title, type: :fulltext
    end

    add_index :workshops, [:inactive, :led_count, :title], if_not_exists: true

    # Join tables
    add_index :categorizable_items, [:categorizable_type, :categorizable_id], if_not_exists: true
    add_index :categorizable_items, :category_id, if_not_exists: true

    add_index :sectorable_items, [:sectorable_type, :sectorable_id], if_not_exists: true
    add_index :sectorable_items, :sector_id, if_not_exists: true
  end

  def down
    # Workshops
    remove_index :workshops, name: 'index_workshops_on_led_count' if index_exists?(:workshops, :led_count, name: 'index_workshops_on_led_count')
    remove_index :workshops, name: 'index_workshops_on_year_and_month' if index_exists?(:workshops, [:year, :month], name: 'index_workshops_on_year_and_month')
    remove_index :workshops, name: 'index_workshops_on_created_at' if index_exists?(:workshops, :created_at, name: 'index_workshops_on_created_at')

    if index_exists?(:workshops, :title, name: 'index_workshops_on_title')
      remove_index :workshops, name: 'index_workshops_on_title'
    end

    remove_index :workshops, name: 'index_workshops_on_inactive_and_led_count' if index_exists?(:workshops, [:inactive, :led_count], name: 'index_workshops_on_inactive_and_led_count')

    # Join tables
    remove_index :categorizable_items, name: 'index_categorizable_items_on_categorizable_type_and_categorizable_id' if index_exists?(:categorizable_items, [:categorizable_type, :categorizable_id], name: 'index_categorizable_items_on_categorizable_type_and_categorizable_id')
    remove_index :categorizable_items, name: 'index_categorizable_items_on_category_id' if index_exists?(:categorizable_items, :category_id, name: 'index_categorizable_items_on_category_id')

    remove_index :sectorable_items, name: 'index_sectorable_items_on_sectorable_type_and_sectorable_id' if index_exists?(:sectorable_items, [:sectorable_type, :sectorable_id], name: 'index_sectorable_items_on_sectorable_type_and_sectorable_id')

    # Only remove sector_id index if no FK references
    if !foreign_key_exists?(:sectorable_items, :sectors) &&
      index_exists?(:sectorable_items, :sector_id, name: 'index_sectorable_items_on_sector_id')
      remove_index :sectorable_items, name: 'index_sectorable_items_on_sector_id'
    end
  end
end
