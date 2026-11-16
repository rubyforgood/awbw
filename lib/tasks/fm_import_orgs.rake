# frozen_string_literal: true

namespace :fm do
  desc "Import every FileMaker organization into portal organizations (round one). Writes; reruns skip finished rows."
  task import_orgs: :environment do
    report = []
    say = ->(line = "") { puts line; report << line }
    $stdout.sync = true
    started = Time.current
    total = FmOrganization.count
    Current.source = "fm_import_orgs"

    say.("Reading #{total} FileMaker organizations…")
    progress = ->(read) { puts "  #{read} / #{total} rows read — #{(Time.current - started).round}s" }

    begin
      import = OrganizationServices::ImportOrgs.new(progress:).call

      say.("\n== Result ==")
      import.results.each { |outcome, messages| say.("#{outcome.to_s.humanize.ljust(18)} #{messages.size}") }
      %i[skipped failed].each do |outcome|
        messages = import.results[outcome]
        next if messages.empty?

        say.("\n#{outcome.to_s.humanize} (#{messages.size}):")
        messages.each { |message| say.("  #{message}") }
      end

      sections = {
        "Rows whose ORG code lands on more than one organization" => import.multi_org,
        "Portal organizations receiving ORG codes from more than one FileMaker organization" => import.condensed,
        "Project codes not in the portal (round 2)" => import.unmatched_project_codes,
        "Duplicate names told apart by code" => import.suffixed,
        "Retired in FileMaker" => import.retired
      }
      sections.each do |heading, lines|
        next if lines.blank?

        say.("\n#{heading} (#{lines.size}):")
        lines.each { |line| say.("  #{line}") }
      end

      tallies = {
        "Status values nothing maps (left blank)" => import.unmatched_statuses,
        "Organization types read as Other, kept as its description" => import.unmatched_types,
        "Staff names no alias answers to (credited to the import user)" => import.unmatched_staff
      }
      tallies.each do |heading, counts|
        next if counts.blank?

        say.("\n#{heading}:")
        counts.sort_by { |name, count| [ -count, name ] }.each { |name, count| say.("  #{count.to_s.rjust(5)}  #{name}") }
      end

      say.("\nTook #{(Time.current - started).round}s.")
      say.("Done.")
    rescue StandardError => e
      say.("\nStopped by #{e.class}: #{e.message} — the batches before this one are saved; rerun to continue.")
      raise
    ensure
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(report.join("\n")), content_type: "text/plain",
          filename: "fm-import-orgs-#{Time.current.strftime("%Y%m%d-%H%M%S")}.txt"
        )
        puts "\nReport saved. Read it back with: bin/rails runner 'puts ActiveStorage::Blob.find(#{blob.id}).download'"
      rescue StandardError => e
        puts "\nCould not save the report (#{e.class}: #{e.message}) — copy the output above."
      end
    end
  end
end
