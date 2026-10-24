# frozen_string_literal: true

# Rewrite stored address countries/states and country/state form answers as the dropdowns
# store them. See AddressServices::TranslateExisting.
#
# Dry-run by default. Set DRY_RUN=false to write changes (each one logged as an Ahoy event).
#   bin/rails data:translate_addresses                 # preview, writes nothing
#   DRY_RUN=false bin/rails data:translate_addresses   # translate + log
namespace :data do
  desc "Translate stored address countries/states and their form answers to dropdown values. Idempotent. DRY_RUN=false to execute."
  task translate_addresses: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    result = AddressServices::TranslateExisting.new(dry_run:).call

    puts "Changes (#{result.changes.values.sum}):"
    result.changes.sort_by { |label, count| [ -count, label ] }.each { |label, count| puts "  #{count.to_s.rjust(5)}  #{label}" }
    result.unmatched.each do |field, values|
      next if values.empty?

      puts "\n#{field.to_s.humanize} values nothing translates (kept as typed — fix by hand):"
      values.sort_by { |value, count| [ -count, value ] }.each { |value, count| puts "  #{count.to_s.rjust(5)}  #{value}" }
    end
    puts "\naddresses changed: #{result.addresses}"
    puts "answers changed:   #{result.answers}"
    puts(dry_run ? "\nDRY RUN — nothing written. Set DRY_RUN=false to execute." : "\nDone.")
  end
end
