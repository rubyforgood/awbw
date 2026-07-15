class SimplifyOrganizationStatuses < ActiveRecord::Migration[8.1]
  # Retiring the six-value status set down to Active / Formerly active / Unknown.
  # Each retired status folds into one of the survivors; Reinstate counts as Active.
  RETIRED_TO_REPLACEMENT = {
    "Reinstate" => "Active",
    "Inactive" => "Formerly active",
    "Suspended" => "Formerly active",
    "Pending" => "Unknown"
  }.freeze

  def up
    %w[Active Unknown].each { |name| OrganizationStatus.find_or_create_by!(name: name) }
    OrganizationStatus.find_or_create_by!(name: "Formerly active")

    RETIRED_TO_REPLACEMENT.each do |old_name, new_name|
      old_status = OrganizationStatus.find_by(name: old_name)
      next unless old_status

      new_status = OrganizationStatus.find_by!(name: new_name)
      # Bulk remap intentionally bypasses callbacks/validations — repointing a FK.
      Organization.where(organization_status_id: old_status.id).update_all(organization_status_id: new_status.id)
      old_status.destroy!
    end
  end

  def down
    # Best effort: recreate the retired status records so they're selectable again.
    # The original per-organization mappings can't be reconstructed.
    RETIRED_TO_REPLACEMENT.each_key { |name| OrganizationStatus.find_or_create_by!(name: name) }
  end
end
