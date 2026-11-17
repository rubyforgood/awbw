# frozen_string_literal: true

namespace :fm do
  desc "Give FileMaker-ended Facilitator affiliations an end date (ADR-0011 round one, pass two). Dry run by default; DRY_RUN=false writes."
  task end_inactive_personnel: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    report = []
    say = ->(line = "") { puts line; report << line }
    $stdout.sync = true
    started = Time.current
    Current.source = AffiliationServices::EndInactivePersonnel::SOURCE
    service = nil
    blob = nil

    begin
      ActiveRecord::Base.transaction do
        service = AffiliationServices::EndInactivePersonnel.new
        total = service.scope.count
        say.("#{"DRY RUN — nothing is saved. " if dry_run}Dating #{total} ended Facilitator affiliations…")
        service = AffiliationServices::EndInactivePersonnel.new(
          progress: ->(read) { puts "  #{read} / #{total} read — #{(Time.current - started).round}s" }
        ).call
        raise ActiveRecord::Rollback if dry_run
      end

      say.("\n== End date set from ==")
      AffiliationServices::EndInactivePersonnel::SOURCES.each do |source, label|
        say.("#{service.results[source].size.to_s.rjust(6)}  #{label}")
      end
      say.("#{service.results[:skipped].size.to_s.rjust(6)}  skipped")
      say.("#{service.results[:failed].size.to_s.rjust(6)}  failed")
      %i[skipped failed].each do |outcome|
        next if service.results[outcome].empty?

        say.("\n#{outcome.to_s.humanize}:")
        service.results[outcome].each { |line| say.("  #{line}") }
      end
      say.("\n#{dry_run ? "DRY RUN — rolled back. Set DRY_RUN=false to write." : "Done."} Took #{(Time.current - started).round}s.")
    rescue StandardError => e
      say.("\nStopped by #{e.class}: #{e.message}")
      raise
    ensure
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(report.join("\n")), content_type: "text/plain",
          filename: "fm-end-inactive-personnel-#{"dry-run-" if dry_run}#{Time.current.strftime("%Y%m%d-%H%M%S")}.txt"
        )
        puts "\nReport saved. Read it back with: bin/rails runner 'puts ActiveStorage::Blob.find(#{blob.id}).download'"
      rescue StandardError => e
        puts "\nCould not save the report (#{e.class}: #{e.message}) — copy the output above."
      end
      if service && !dry_run
        Ahoy::Tracker.new(user: Setting.import_user).track(
          "end_dates.affiliation",
          { source: Current.source, report_blob_id: blob&.id, **service.results.transform_values(&:size) }
        )
      end
    end
  end
end
