# frozen_string_literal: true

# Remove fake form-submission test data. Thin wrapper around FakeSubmissionRemover
# (app/services/fake_submission_remover.rb) — see it for the full deletion graph
# and the rules that protect real people.
#
# Usage (dry run — prints what WOULD be deleted, changes nothing):
#   bin/rails data:remove_fake_submissions PERSON_IDS=12,34,56
#   bin/rails data:remove_fake_submissions FORM_SUBMISSION_IDS=78,90
#
# To actually delete, add CONFIRM=true:
#   bin/rails data:remove_fake_submissions PERSON_IDS=12,34 CONFIRM=true
#
# DELETE_USERS=true also removes a person's unused auto-created account (never a
# super_user or anyone who has signed in / has activity).
#
# FORCE=true overrides ALL protections and deletes even people who look real
# (destroying any linked account). Use only for confirmed false positives.
namespace :data do
  desc "Remove fake form-submission people and their full data + audit graph (dry run unless CONFIRM=true)"
  task remove_fake_submissions: :environment do
    parse_ids = ->(raw) { raw.to_s.split(",").map(&:strip).reject(&:blank?).map(&:to_i).uniq }

    person_ids = parse_ids.call(ENV["PERSON_IDS"])
    submission_ids = parse_ids.call(ENV["FORM_SUBMISSION_IDS"])
    confirm = ENV["CONFIRM"] == "true"

    if person_ids.empty? && submission_ids.empty?
      abort "Provide PERSON_IDS=1,2,3 and/or FORM_SUBMISSION_IDS=4,5,6"
    end

    remover = FakeSubmissionRemover.new(
      person_ids: person_ids,
      form_submission_ids: submission_ids,
      delete_users: ENV["DELETE_USERS"] == "true",
      force: ENV["FORCE"] == "true"
    )

    puts "\n⚠️  WARNING: This task is ONLY for removing people created by FAKE form"
    puts "    submissions. It deletes a person and their entire data + audit graph."
    puts "    Do NOT use it to delete a regular/real person — verify every id is fake"
    puts "    against the dry-run output before re-running with CONFIRM=true.\n"

    if remover.missing_form_submission_ids.any?
      puts "Warning: FormSubmission ids not found: #{remover.missing_form_submission_ids.sort.join(', ')}"
    end
    if remover.missing_person_ids.any?
      puts "Warning: Person ids not found: #{remover.missing_person_ids.sort.join(', ')}"
    end

    if remover.skipped.any?
      puts "\nSkipping #{remover.skipped.size} person(s) that look real:"
      remover.skipped.each do |skip|
        puts "  ##{skip.person.id} #{skip.person.full_name_with_email} — #{skip.reasons.join(', ')}"
      end
    end

    if remover.deletable.empty?
      puts "\nNothing to delete."
      next
    end

    puts "\n#{confirm ? 'DELETING' : 'DRY RUN — would delete'} for #{remover.deletable.size} person(s):"
    remover.deletable.each { |person| puts "  ##{person.id} #{person.full_name_with_email}" }
    puts "\nRecords:"
    remover.counts.each { |label, count| puts "  #{label.to_s.tr('_', ' ').capitalize.ljust(21)}#{count}" }

    unless confirm
      puts "\nDry run only. Re-run with CONFIRM=true to delete."
      next
    end

    begin
      deleted = remover.call
      puts "\nDone. Deleted #{deleted.size} person(s) and their data + audit graph."
    rescue ActiveRecord::InvalidForeignKey => e
      abort "\nAborted (nothing deleted): a linked User Account owns content that " \
            "can't be orphaned (workshops, reports, stories, etc.). Reassign or " \
            "remove it first.\n#{e.message}"
    end
  end
end
