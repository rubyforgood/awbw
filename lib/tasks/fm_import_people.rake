# frozen_string_literal: true

# Create people from the FileMaker Rolodex archive (fm_rolodexes, loaded by fm:import).
# See PersonServices::ImportFromRolodex for the match/link/fill/create rules. Idempotent:
# a row whose ID is already some person's filemaker_code is left alone.
#
# Dry-run by default. Set DRY_RUN=false to write changes; VERBOSE=true lists every row.
#   bin/rails fm:import_people                 # preview, writes nothing
#   DRY_RUN=false bin/rails fm:import_people   # create + link people
namespace :fm do
  desc "Create people from FileMaker Rolodex archive rows (link existing by name + email). Idempotent. DRY_RUN=false to execute."
  task import_people: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    verbose = ENV["VERBOSE"] == "true"
    detailed = verbose ? PersonServices::ImportFromRolodex::OUTCOMES : %i[failed]
    import = nil

    ActiveRecord::Base.transaction do
      import = PersonServices::ImportFromRolodex.new.call
      raise ActiveRecord::Rollback if dry_run
    end

    import.results.each do |outcome, messages|
      next unless detailed.include?(outcome) && messages.any?

      puts "\n#{outcome.to_s.humanize} (#{messages.size}):"
      messages.each { |message| puts "  #{message}" }
    end

    if import.differences.any?
      puts "\nKept the portal's value where FileMaker differs (#{import.differences.size}, also left as a comment on each person):"
      import.differences.each { |difference| puts "  #{difference}" }
    end

    if import.unmatched_tags.any?
      puts "\nTerms no sector, age group or recorded translation answers to:"
      import.unmatched_tags.sort_by { |name, count| [ -count, name ] }.each { |name, count| puts "  #{count.to_s.rjust(5)}  #{name}" }
    end

    puts
    import.results.each { |outcome, messages| puts "#{outcome.to_s.humanize.ljust(17)} #{messages.size}" }
    puts(dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "\nDone.")
  end
end
