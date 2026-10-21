# frozen_string_literal: true

# Create people from the FileMaker Rolodex archive (fm_rolodexes, loaded by fm:import).
# See PersonServices::ImportFromRolodex for the match/link/fill/create rules. Idempotent:
# a row whose ID is already some person's filemaker_code is left alone.
#
# Dry-run by default. Set DRY_RUN=false to write changes; VERBOSE=true lists every row.
# A real run commits every ImportFromRolodex::BATCH_SIZE rows, so stopping partway keeps
# what it finished and the rerun skips it. The full report is also saved as an ActiveStorage
# blob — the run prints the command that reads it back — so a lost console doesn't lose it.
# FM_IDS names the rows to run, and reads them even though a person already carries the
# ID — how a match reported under "failed" is picked up once the person it named is valid.
#   bin/rails fm:import_people                 # preview, writes nothing
#   DRY_RUN=false bin/rails fm:import_people   # create + link people
#   FM_IDS=00024,00031 DRY_RUN=false bin/rails fm:import_people   # just these rows, again
namespace :fm do
  desc "Create people from FileMaker Rolodex archive rows (link existing by name + email). Idempotent. DRY_RUN=false to execute, FM_IDS to re-run named rows."
  task import_people: :environment do
    if TagAlias.none?
      abort "No tag aliases recorded — run bin/rails data:seed_tag_aliases first, or every legacy term lands in the unmatched report."
    end

    dry_run = ENV["DRY_RUN"] != "false"
    verbose = ENV["VERBOSE"] == "true"
    detailed = verbose ? PersonServices::ImportFromRolodex::OUTCOMES : %i[failed]
    fm_ids = ENV["FM_IDS"].to_s.split(",").map(&:strip).compact_blank
    scope = fm_ids.any? ? FmRolodex.where(fm_id: fm_ids) : FmRolodex.all
    report = []
    say = ->(line = "") { puts line; report << line }
    $stdout.sync = true

    begin
      say.("Reading #{fm_ids.size} named row(s) again, already imported or not: #{fm_ids.join(", ")}") if fm_ids.any?
      total = scope.count
      started = Time.current
      progress = ->(read) { puts "  #{read} / #{total} rows read — #{(Time.current - started).round}s" }
      import = nil

      ActiveRecord::Base.transaction do
        import = PersonServices::ImportFromRolodex.new(scope:, relink: fm_ids.any?, progress:).call
        raise ActiveRecord::Rollback if dry_run
      end

      import.results.each do |outcome, messages|
        next unless detailed.include?(outcome) && messages.any?

        say.("\n#{outcome.to_s.humanize} (#{messages.size}):")
        messages.each { |message| say.("  #{message}") }
      end

      if import.differences.any?
        say.("\nKept the portal's value where FileMaker differs (#{import.differences.size}, also left as a comment on each person):")
        import.differences.each { |difference| say.("  #{difference}") }
      end

      if import.unmatched_tags.any?
        say.("\nTerms no sector, age group or recorded translation answers to:")
        import.unmatched_tags.sort_by { |name, count| [ -count, name ] }.each { |name, count| say.("  #{count.to_s.rjust(5)}  #{name}") }
      end

      if import.unmatched_staff.any?
        say.("\nStaff names no portal user answers to (record them with data:load_staff_aliases):")
        import.unmatched_staff.sort_by { |name, count| [ -count, name ] }.each { |name, count| say.("  #{count.to_s.rjust(5)}  #{name}") }
      end

      say.()
      import.results.each { |outcome, messages| say.("#{outcome.to_s.humanize.ljust(17)} #{messages.size}") }
      say.("Took #{(Time.current - started).round}s.")
      say.(dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "\nDone.")
    rescue StandardError => e
      say.("\nStopped by #{e.class}: #{e.message}#{" — the batches before this one are saved; rerun to continue." unless dry_run}")
      raise
    ensure
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(report.join("\n")), content_type: "text/plain",
          filename: "fm-import-people-#{Time.current.strftime("%Y%m%d-%H%M%S")}#{"-dry-run" if dry_run}.txt"
        )
        puts "\nReport saved. Read it back with: bin/rails runner 'puts ActiveStorage::Blob.find(#{blob.id}).download'"
      rescue StandardError => e
        puts "\nCould not save the report (#{e.class}: #{e.message}) — copy the output above."
      end
    end
  end
end
