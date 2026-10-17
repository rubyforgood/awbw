# frozen_string_literal: true

# Backfill resources.organization_id from the legacy free-text `agency` column.
# See ResourceServices::ResolveOrganizations — also runnable from admin Data health.
#
# Dry-run by default. Set DRY_RUN=false to write changes.
#   bin/rails data:resolve_resource_organizations             # preview, writes nothing
#   DRY_RUN=false bin/rails data:resolve_resource_organizations  # link + create
namespace :data do
  desc "Link resources to organizations from the legacy `agency` name (match/create). Idempotent. DRY_RUN=false to execute."
  task resolve_resource_organizations: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    result = ResourceServices::ResolveOrganizations.new(dry_run: dry_run, log: method(:puts)).call

    puts
    puts "linked to existing: #{result.linked - result.created}"
    puts "orgs created:       #{result.created}"
    puts(dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "\nDone.")
  end
end
