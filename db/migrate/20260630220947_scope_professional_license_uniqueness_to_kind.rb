class ScopeProfessionalLicenseUniquenessToKind < ActiveRecord::Migration[8.1]
  # A license is identified by its kind + number, so the same number under two
  # different kinds (e.g. "LMFT 12345" and "LCSW 12345") are distinct licenses.
  # Widen the per-person unique index from (number) to (kind, number).
  def up
    if index_exists?(:professional_licenses, [ :person_id, :number ], name: "index_professional_licenses_on_person_and_number")
      remove_index :professional_licenses, name: "index_professional_licenses_on_person_and_number"
    end
    unless index_exists?(:professional_licenses, [ :person_id, :kind, :number ], name: "index_professional_licenses_on_person_kind_number")
      add_index :professional_licenses, [ :person_id, :kind, :number ], unique: true,
        name: "index_professional_licenses_on_person_kind_number"
    end
  end

  def down
    if index_exists?(:professional_licenses, [ :person_id, :kind, :number ], name: "index_professional_licenses_on_person_kind_number")
      remove_index :professional_licenses, name: "index_professional_licenses_on_person_kind_number"
    end
    unless index_exists?(:professional_licenses, [ :person_id, :number ], name: "index_professional_licenses_on_person_and_number")
      add_index :professional_licenses, [ :person_id, :number ], unique: true,
        name: "index_professional_licenses_on_person_and_number"
    end
  end
end
