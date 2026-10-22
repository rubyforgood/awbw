class AddCeAccreditationToSettings < ActiveRecord::Migration[8.1]
  COLUMNS = { ce_administrator_title: :string, ce_accreditation_body: :string, ce_accreditation_url: :string }.freeze

  def up
    COLUMNS.each do |name, type|
      add_column :settings, name, type unless column_exists?(:settings, name)
    end
  end

  def down
    COLUMNS.each_key { |name| remove_column :settings, name, if_exists: true }
  end
end
