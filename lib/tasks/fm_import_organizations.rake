# frozen_string_literal: true

# Bring FileMaker's organizations, projects and the ties between them and people into the
# portal (ADR-0008). Run after fm:import_people, which makes the people; this pass finds them
# by their Rolodex code. Two steps, in order:
#   1. OrganizationServices::ImportFromFilemaker — organizations, projects (as programs nested
#      under them), their addresses, phones, emails, and agencies' own Rolodex cards
#   2. AffiliationServices::ImportFromFilemaker — personnel, people-to-organizations, and each
#      Rolodex card's organization, title and work addresses
# Both are idempotent: a row whose code a record already carries is left alone.
#
# Dry-run by default. Set DRY_RUN=false to write changes; VERBOSE=true lists every row.
# A real run commits each batch as it goes, so stopping partway keeps what it finished and
# the rerun skips it. The full report is also saved as an ActiveStorage blob. Every record a
# run creates or fills is logged under the run's name, which fm:undo_import reverses:
#   bin/rails fm:import_organizations                 # preview, writes nothing
#   DRY_RUN=false bin/rails fm:import_organizations   # create + link
#   DRY_RUN=false bin/rails fm:undo_import RUN=fm-import-organizations-20261022134055
namespace :fm do
  desc "Create organizations and affiliations from the FileMaker archive (after fm:import_people). Idempotent. DRY_RUN=false to execute."
  task import_organizations: :environment do
    unless Setting.import_user
      abort "No import user chosen — pick one on /admin/settings (Imports); it's credited as created_by/updated_by when FileMaker names no staffer we can resolve."
    end

    dry_run = ENV["DRY_RUN"] != "false"
    verbose = ENV["VERBOSE"] == "true"
    report = []
    say = ->(line = "") { puts line; report << line }
    $stdout.sync = true

    begin
      run = "fm-import-organizations-#{Time.current.strftime("%Y%m%d%H%M%S")}"
      Current.source = "fm_import_organizations"
      say.("Run #{run}#{" (dry run)" if dry_run}")
      started = Time.current
      steps = {
        "Organizations and projects" => OrganizationServices::ImportFromFilemaker,
        "Affiliations and work addresses" => AffiliationServices::ImportFromFilemaker
      }
      imports = {}

      run_steps = lambda do
        steps.each do |title, service|
          say.("\n#{title}…")
          progress = ->(read) { puts "  #{read} rows read — #{(Time.current - started).round}s" }
          imports[title] = service.new(progress:, run:).call
        end
      end

      # A dry run rolls back as a whole; a real one lets each batch commit as it goes.
      if dry_run
        ActiveRecord::Base.transaction do
          run_steps.call
          raise ActiveRecord::Rollback
        end
      else
        run_steps.call
      end

      imports.each do |title, import|
        say.("\n== #{title} ==")
        import.results.each do |outcome, messages|
          next unless (verbose || %i[failed skipped].include?(outcome)) && messages.any?

          say.("\n#{outcome.to_s.humanize} (#{messages.size}):")
          messages.each { |message| say.("  #{message}") }
        end

        if import.differences.any?
          say.("\nKept the portal's value where FileMaker differs (#{import.differences.size}, also left as a comment):")
          import.differences.each { |difference| say.("  #{difference}") }
        end

        tallies = {
          "Organization types read as Other, kept as its description" => import.try(:unmatched_types),
          "Personnel Status values and how they were read" => import.try(:statuses),
          "Personnel roles" => import.try(:roles),
          "Address countries nothing translates (left blank)" => import.try(:unmatched_addresses)&.fetch(:country, nil),
          "Address states nothing translates (kept as typed)" => import.try(:unmatched_addresses)&.fetch(:state, nil)
        }
        tallies.each do |heading, counts|
          next if counts.blank?

          say.("\n#{heading}:")
          counts.sort_by { |name, count| [ -count, name ] }.each { |name, count| say.("  #{count.to_s.rjust(5)}  #{name}") }
        end

        say.()
        import.results.each { |outcome, messages| say.("#{outcome.to_s.humanize.ljust(17)} #{messages.size}") }
      end

      say.("\nTook #{(Time.current - started).round}s.")
      say.(dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "\nDone.")
      say.("To reverse this run: DRY_RUN=false bin/rails fm:undo_import RUN=#{run}") unless dry_run
    rescue StandardError => e
      say.("\nStopped by #{e.class}: #{e.message}#{" — the batches before this one are saved; rerun to continue." unless dry_run}")
      raise
    ensure
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(report.join("\n")), content_type: "text/plain",
          filename: "fm-import-organizations-#{Time.current.strftime("%Y%m%d-%H%M%S")}#{"-dry-run" if dry_run}.txt"
        )
        puts "\nReport saved. Read it back with: bin/rails runner 'puts ActiveStorage::Blob.find(#{blob.id}).download'"
      rescue StandardError => e
        puts "\nCould not save the report (#{e.class}: #{e.message}) — copy the output above."
      end
    end
  end

  desc "Reverse any FileMaker import run (RUN=fm-import-…) from the activity it logged. Dry-run by default; DRY_RUN=false to execute."
  task undo_import: :undo_import_people
end
