# frozen_string_literal: true

# Backfill resources.organization_id from the legacy free-text `agency` column.
#
# For each resource that has an `agency` name but no organization linked yet:
#   - match an Organization by exact, case-insensitive name (agency == org.name)
#   - exactly one match   -> link it
#   - no match            -> create the Organization, link it
#   - more than one match -> ambiguous; skip and report (reconcile by hand)
#
# New orgs get status "Unknown" — not because the link cares (it doesn't), but
# because Organization requires organization_status_id (org status is legacy and
# no longer consulted, ADR-0003 D4). "Unknown" is the honest value for an org
# minted from a stale free-text name.
#
# Idempotent (only touches rows where organization_id IS NULL) and safe to run
# while the app still keeps the `agency` column. Drop the column in a follow-up
# once this has run in prod.
#
# Dry-run by default. Set DRY_RUN=false to write changes.
#   bin/rails data:resolve_resource_organizations             # preview, writes nothing
#   DRY_RUN=false bin/rails data:resolve_resource_organizations  # link + create
namespace :data do
  desc "Link resources to organizations from the legacy `agency` name (match/create). Idempotent. DRY_RUN=false to execute."
  task resolve_resource_organizations: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    unknown_status = OrganizationStatus.find_by(name: "Unknown")
    raise "OrganizationStatus \"Unknown\" is required to create organizations" if !dry_run && unknown_status.nil?

    linked = created = ambiguous = 0
    created_by_name = {}

    ActiveRecord::Base.transaction do
      Resource.where.not(agency: [ nil, "" ]).where(organization_id: nil).find_each do |resource|
        name = resource.agency.strip
        next if name.blank?
        key = name.downcase

        matches = Organization.where("LOWER(name) = ?", key).to_a
        if matches.size > 1
          ambiguous += 1
          puts "  ! resource ##{resource.id} #{resource.title.inspect}: #{matches.size} orgs named #{name.inspect} (ids: #{matches.map(&:id).join(', ')}) — skipped"
          next
        end

        if (organization = matches.first)
          linked += 1
          puts "  = resource ##{resource.id}: link existing org ##{organization.id} #{name.inspect}"
        elsif created_by_name.key?(key)
          organization = created_by_name[key] # nil during a dry run
          linked += 1
          puts "  = resource ##{resource.id}: link org created earlier this run #{name.inspect}"
        else
          organization = dry_run ? nil : Organization.create!(name: name, organization_status: unknown_status)
          created_by_name[key] = organization
          created += 1
          puts "  + resource ##{resource.id}: create + link org #{name.inspect}"
        end

        resource.update_column(:organization_id, organization.id) if organization && !dry_run
      end

      raise ActiveRecord::Rollback if dry_run
    end

    puts
    puts "linked to existing: #{linked}"
    puts "orgs created:       #{created}"
    puts "ambiguous, skipped: #{ambiguous}"
    puts(dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "\nDone.")
  end
end
