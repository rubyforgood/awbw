class AddCeAccreditationAbbreviationToSettings < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:settings, :ce_accreditation_abbreviation)
      add_column :settings, :ce_accreditation_abbreviation, :string
    end
  end

  def down
    remove_column :settings, :ce_accreditation_abbreviation, if_exists: true
  end
end
