# frozen_string_literal: true

# Rewrite stored address countries/states and country/state form answers as the dropdowns
# store them. See AddressServices::TranslateExisting.
#
# Dry-run by default. Set DRY_RUN=false to write changes (each one logged as an Ahoy event
# credited to Setting.import_user, which a real run requires).
# Every run, dry or not, also saves its report as an ActiveStorage blob — the command to
# read it back is printed at the end.
#   bin/rails data:translate_addresses                 # preview, writes nothing
#   VERBOSE=true bin/rails data:translate_addresses    # also print every change as CSV rows
#   DRY_RUN=false bin/rails data:translate_addresses   # translate + log
namespace :data do
  desc "Translate stored address countries/states and their form answers to dropdown values. Idempotent. DRY_RUN=false to execute."
  task translate_addresses: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    verbose = ENV["VERBOSE"] == "true"
    import_user = Setting.import_user
    if !dry_run && import_user.nil?
      abort "No import user chosen — pick one in admin Settings (Imports); every change this run logs is credited to them."
    end
    report = []
    say = ->(line = "") { puts line; report << line }
    # Every change goes in the saved report; the console shows them only when VERBOSE=true.
    note = ->(line) { puts line if verbose; report << line }
    $stdout.sync = true

    begin
      result = AddressServices::TranslateExisting.new(dry_run:, user: import_user).call

      say.("Changes (#{result.changes.values.sum}):")
      result.changes.sort_by { |label, count| [ -count, label ] }.each { |label, count| say.("  #{count.to_s.rjust(5)}  #{label}") }
      result.unmatched.each do |field, values|
        next if values.empty?

        outcome = field == :country ? "left blank, was logged" : "kept as typed"
        say.("\n#{field.to_s.humanize} values nothing translates (#{outcome} — fix by hand if you know it):")
        values.sort_by { |value, count| [ -count, value ] }.each { |value, count| say.("  #{count.to_s.rjust(5)}  #{value}") }
      end
      say.("\nEvery change (CSV#{", in the saved report — VERBOSE=true prints them here" unless verbose}):")
      note.(CSV.generate_line(AddressServices::TranslateExisting::ROW_HEADERS, row_sep: ""))
      result.rows.each { |row| note.(CSV.generate_line(row.to_h.values, row_sep: "")) }
      say.("\naddresses changed: #{result.addresses}")
      say.("answers changed:   #{result.answers}")
      say.(dry_run ? "\nDRY RUN — nothing written. Set DRY_RUN=false to execute." : "\nDone.")
    rescue StandardError => e
      say.("\nStopped by #{e.class}: #{e.message}#{" — nothing was written; rerun to continue." unless dry_run}")
      raise
    ensure
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(report.join("\n")), content_type: "text/plain",
          filename: "translate-addresses-#{Time.current.strftime("%Y%m%d-%H%M%S")}#{"-dry-run" if dry_run}.txt"
        )
        puts "\nReport saved. Read it back with: bin/rails runner 'puts ActiveStorage::Blob.find(#{blob.id}).download'"
      rescue StandardError => e
        puts "\nCould not save the report (#{e.class}: #{e.message}) — copy the output above."
      end
    end
  end
end
