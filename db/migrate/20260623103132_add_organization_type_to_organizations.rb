class AddOrganizationTypeToOrganizations < ActiveRecord::Migration[8.0]
  # The canonical classifications previously hardcoded in the organization and
  # registration forms. We seed them as published OrganizationTypes and map each
  # organization's legacy `agency_type` string onto the matching record so no
  # existing data is lost when the form switches to the association.
  DEFAULT_NAMES = [
    "501c3/nonprofit",
    "For-profit",
    "Government agency",
    "Other"
  ].freeze

  # Legacy `agency_type` strings that should map onto a renamed type, so existing
  # organizations that picked the old wording still land on the right record.
  LEGACY_ALIASES = { "Other (please specify below)" => "Other" }.freeze

  def up
    unless column_exists?(:organizations, :organization_type_id)
      add_reference :organizations, :organization_type, foreign_key: true, null: true, index: true
    end

    org_type = Class.new(ActiveRecord::Base) { self.table_name = "organization_types" }
    organization = Class.new(ActiveRecord::Base) { self.table_name = "organizations" }

    DEFAULT_NAMES.each do |name|
      record = org_type.where("LOWER(name) = LOWER(?)", name).first
      record ||= org_type.create!(name: name)
      record.update!(published: true)
    end

    organization.where.not(agency_type: [ nil, "" ]).find_each do |org|
      name = LEGACY_ALIASES[org.agency_type] || org.agency_type
      match = org_type.where("LOWER(name) = LOWER(?)", name).first
      org.update_columns(organization_type_id: match.id) if match
    end
  end

  def down
    remove_reference :organizations, :organization_type, foreign_key: true, if_exists: true
  end
end
