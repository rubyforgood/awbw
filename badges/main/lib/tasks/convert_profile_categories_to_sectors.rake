# frozen_string_literal: true

# Give people an additional sector for each profile-specific category tag (the retired
# workshop settings), translated through the tag aliases (ProfileCategoriesToSectors).
# Run data:seed_tag_aliases first so the aliases exist.
#
# Dry-run by default. Set DRY_RUN=false to write changes.
#   bin/rails data:convert_profile_categories_to_sectors             # preview, writes nothing
#   DRY_RUN=false bin/rails data:convert_profile_categories_to_sectors  # add the sectors
namespace :data do
  desc "Add people's profile-specific category tags as additional sectors via tag aliases. Idempotent. DRY_RUN=false to execute."
  task convert_profile_categories_to_sectors: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    result = ProfileCategoriesToSectors.new(dry_run: dry_run, log: method(:puts)).call

    puts
    puts "sectors added:      #{result.added} (#{result.people} people)"
    puts "not translated:     #{result.unmatched.map { |term, count| "#{term} (#{count})" }.join(', ').presence || 'none'}"
    puts "org tags left as-is: #{result.organization_tags}"
    puts(dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "\nDone.")
  end
end
