class ScopeProfessionalLicenseUniquenessToKind < ActiveRecord::Migration[8.1]
  # A license is identified by kind + number, not number alone, so "LMFT 12345"
  # and "LCSW 12345" are distinct. Widen the per-person unique index.
  def change
    remove_index :professional_licenses, [ :person_id, :number ], unique: true,
      name: "index_professional_licenses_on_person_and_number"
    add_index :professional_licenses, [ :person_id, :kind, :number ], unique: true,
      name: "index_professional_licenses_on_person_kind_number"
  end
end
