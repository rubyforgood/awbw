# frozen_string_literal: true

# Bring FileMaker's organizations, projects and the ties between them and people into the
# portal (ADR-0008), as two runs so each can be checked and reversed on its own:
#   1. fm:import_organizations — after fm:import_people:
#      a. PersonServices::ImportFromRolodex over agency cards only — the contact person an
#         agency card names, which fm:import_people skipped
#      b. OrganizationServices::ImportFromFilemaker — organizations, projects (as programs
#         nested under them), their addresses, phones, emails, agencies' own Rolodex cards,
#         and the organization a card names for someone staffing an unimported project
#   2. fm:import_affiliations — AffiliationServices::ImportFromFilemaker, after the first:
#      personnel, people-to-organizations, and each Rolodex card's organization, title and
#      work addresses
# Each is idempotent: a row whose code a record already carries is left alone.
#
# Dry-run by default. Set DRY_RUN=false to write changes; VERBOSE=true lists every row.
# A real run commits each batch as it goes, so stopping partway keeps what it finished and
# the rerun skips it. The full report is also saved as an ActiveStorage blob. Every record a
# run creates or fills is logged under the run's name, which fm:undo_import reverses. Undo the
# affiliations run before the organizations run — an organization someone is affiliated with
# is kept.
# FM_IDS names the archive rows to read, by their own ID — for organizations, an organization,
# a project, an agency card or a personnel record (an organization and its projects come as a
# pair either way, since one can't be read without the other); for affiliations, a personnel
# record, a people-to-organizations record, or a Rolodex card:
#   bin/rails fm:import_organizations                 # preview, writes nothing
#   DRY_RUN=false bin/rails fm:import_organizations   # create + link organizations
#   DRY_RUN=false bin/rails fm:import_affiliations    # then the affiliations
#   FM_IDS=ORG02184,P1630 DRY_RUN=false bin/rails fm:import_organizations   # just these rows
#   DRY_RUN=false bin/rails fm:undo_import RUN=fm-import-affiliations-20261022134055
namespace :fm do
  import_from_archive = lambda do |task_name, steps|
    unless Setting.import_user
      abort "No import user chosen — pick one on /admin/settings (Imports); it's credited as created_by/updated_by when FileMaker names no staffer we can resolve."
    end
    unless StaffAlias.exists?
      abort "No staff aliases recorded — run bin/rails data:load_staff_aliases FILE=… first, or every record is credited to the import user."
    end

    dry_run = ENV["DRY_RUN"] != "false"
    verbose = ENV["VERBOSE"] == "true"
    fm_ids = ENV["FM_IDS"].to_s.split(",").map(&:strip).compact_blank
    slug = "fm-#{task_name.dasherize}"
    report = []
    say = ->(line = "") { puts line; report << line }
    $stdout.sync = true

    begin
      run = "#{slug}-#{Time.current.strftime("%Y%m%d%H%M%S")}"
      Current.source = "fm_#{task_name}"
      say.("Run #{run}#{" (dry run)" if dry_run}")
      say.("Reading #{fm_ids.size} named row(s): #{fm_ids.join(", ")}") if fm_ids.any?
      started = Time.current
      imports = {}

      run_steps = lambda do
        steps.each do |title, build|
          say.("\n#{title}…")
          progress = ->(read) { puts "  #{read} rows read — #{(Time.current - started).round}s" }
          imports[title] = build.call(fm_ids:, progress:, run:).call
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

        if import.try(:differences).present?
          say.("\nKept the portal's value where FileMaker differs (#{import.differences.size}, also left as a comment):")
          import.differences.each { |difference| say.("  #{difference}") }
        end

        if import.try(:nested).present?
          say.("\nNested under their FileMaker parent (ParentID) (#{import.nested.size}):")
          import.nested.each { |line| say.("  #{line}") }
        end

        if import.try(:unplaced).present?
          say.("\nProjects whose place couldn't be saved, missing a city or state (#{import.unplaced.size}):")
          import.unplaced.each { |line| say.("  #{line}") }
        end

        tallies = {
          "Organization types read as Other, kept as its description" => import.try(:unmatched_types),
          "Staff names no alias answers to (credited to the import user; record them with data:load_staff_aliases)" => import.try(:unmatched_staff),
          "Personnel Status values and how they were read" => import.try(:statuses),
          "Personnel roles" => import.try(:roles),
          "Address countries nothing translates (left blank)" => import.try(:unmatched_addresses)&.fetch(:country, nil),
          "Address states nothing translates (kept as typed)" => import.try(:unmatched_addresses)&.fetch(:state, nil),
          "Address types nothing translates (a person's left unknown; an organization's are work)" =>
            import.try(:unmatched_addresses)&.fetch(:address_type, nil),
          "Phone types nothing translates (left unknown)" => import.try(:unmatched_phone_types)
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
          filename: "#{slug}-#{Time.current.strftime("%Y%m%d-%H%M%S")}#{"-dry-run" if dry_run}.txt"
        )
        puts "\nReport saved. Read it back with: bin/rails runner 'puts ActiveStorage::Blob.find(#{blob.id}).download'"
      rescue StandardError => e
        puts "\nCould not save the report (#{e.class}: #{e.message}) — copy the output above."
      end
    end
  end

  desc "Create organizations, and the people agency cards name, from the FileMaker archive (after fm:import_people). Idempotent. DRY_RUN=false to execute."
  task import_organizations: :environment do
    import_from_archive.call("import_organizations", {
      # The people pass skipped every agency card, so the contact person one names comes in
      # here — only those cards, leaving everyone fm:import_people already brought over alone.
      "People named on agency cards" => lambda do |fm_ids:, progress:, run:|
        cards = fm_ids.any? ? FmRolodex.agency_cards.where(fm_id: fm_ids) : FmRolodex.agency_cards
        PersonServices::ImportFromRolodex.new(scope: cards, relink: fm_ids.any?, progress:, run:)
      end,
      "Organizations and projects" => ->(**options) { OrganizationServices::ImportFromFilemaker.new(**options) }
    })
  end

  desc "Create affiliations from the FileMaker archive (after fm:import_organizations). Idempotent. DRY_RUN=false to execute."
  task import_affiliations: :environment do
    import_from_archive.call("import_affiliations", {
      "Affiliations and work addresses" => ->(**options) { AffiliationServices::ImportFromFilemaker.new(**options) }
    })
  end

  desc "Reverse any FileMaker import run (RUN=fm-import-…) from the activity it logged. Dry-run by default; DRY_RUN=false to execute."
  task undo_import: :undo_import_people
end
