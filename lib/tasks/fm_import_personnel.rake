# frozen_string_literal: true

namespace :fm do
  desc "Import FileMaker Personnel as Facilitator affiliations (ADR-0011 round one). Writes; reruns skip finished rows."
  task import_personnel: :environment do
    abort "Choose an import user on the app settings page first — new affiliations are credited to it." unless Setting.import_user

    report = []
    say = ->(line = "") { puts line; report << line }
    $stdout.sync = true
    started = Time.current
    total = FmPersonnel.count
    Current.source = "fm_import_personnel"

    say.("Reading #{total} FileMaker Personnel rows…")
    progress = ->(read) { puts "  #{read} / #{total} rows read — #{(Time.current - started).round}s" }
    import = nil
    blob = nil

    begin
      import = AffiliationServices::ImportPersonnel.new(progress:).call

      say.("\n== Result ==")
      import.results.each { |outcome, messages| say.("#{outcome.to_s.humanize.ljust(18)} #{messages.size}") }

      tallies = {
        "Skipped, by reason (review with the saved Blazer queries)" => import.skip_reasons,
        "Roles read" => import.roles,
        "Statuses read" => import.statuses,
        "Staff names no alias answers to (credited to the import user)" => import.unmatched_staff
      }
      tallies.each do |heading, counts|
        next if counts.blank?

        say.("\n#{heading}:")
        counts.sort_by { |name, count| [ -count, name ] }.each { |name, count| say.("  #{count.to_s.rjust(5)}  #{name}") }
      end

      %i[skipped failed].each do |outcome|
        messages = import.results[outcome]
        next if messages.empty?

        say.("\n#{outcome.to_s.humanize} (#{messages.size}):")
        messages.each { |message| say.("  #{message}") }
      end

      say.("\nEnded rows with no end date read as running until fm:end_inactive_personnel dates them.")
      say.("Took #{(Time.current - started).round}s.")
      say.("Done.")
    rescue StandardError => e
      say.("\nStopped by #{e.class}: #{e.message} — the batches before this one are saved; rerun to continue.")
      raise
    ensure
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(report.join("\n")), content_type: "text/plain",
          filename: "fm-import-personnel-#{Time.current.strftime("%Y%m%d-%H%M%S")}.txt"
        )
        puts "\nReport saved. Read it back with: bin/rails runner 'puts ActiveStorage::Blob.find(#{blob.id}).download'"
      rescue StandardError => e
        puts "\nCould not save the report (#{e.class}: #{e.message}) — copy the output above."
      end
      if import
        Ahoy::Tracker.new(user: Setting.import_user).track(
          "import.affiliation",
          { source: Current.source, report_blob_id: blob&.id,
            **import.results.transform_values(&:size), skip_reasons: import.skip_reasons }
        )
      end
    end
  end
end
