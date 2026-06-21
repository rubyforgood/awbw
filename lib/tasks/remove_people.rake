# frozen_string_literal: true

# Permanently remove people and ALL their associated data. Thin wrapper around
# PeopleRemover (app/services/people_remover.rb) — see it for the full deletion
# graph and the rules that protect real people. The original use case is cleaning
# up fake form-submission test data; FORM_SUBMISSION_IDS resolves those to their
# owning people.
#
# Usage (dry run — prints what WOULD be deleted, changes nothing):
#   bin/rails data:remove_people PERSON_IDS=12,34,56
#   bin/rails data:remove_people FORM_SUBMISSION_IDS=78,90
#
# To actually delete, add CONFIRM=true:
#   bin/rails data:remove_people PERSON_IDS=12,34 CONFIRM=true
#
# DELETE_USERS=true also removes a person's unused auto-created account (never a
# super_user or anyone who has signed in / has activity).
#
# FORCE=true overrides ALL protections and deletes even people who look real
# (destroying any linked account). Use only for confirmed false positives.
#
# The deletion is attributed to an admin actor for the Ahoy audit trail: by
# default umberto.user@example.com, overridable with ACTOR_EMAIL=someone@example.com.
namespace :data do
  desc "Permanently remove people and their full data + audit graph (dry run unless CONFIRM=true)"
  task remove_people: :environment do
    parse_ids = ->(raw) { raw.to_s.split(",").map(&:strip).reject(&:blank?).map(&:to_i).uniq }

    person_ids = parse_ids.call(ENV["PERSON_IDS"])
    submission_ids = parse_ids.call(ENV["FORM_SUBMISSION_IDS"])
    confirm = ENV["CONFIRM"] == "true"

    if person_ids.empty? && submission_ids.empty?
      abort "Provide PERSON_IDS=1,2,3 and/or FORM_SUBMISSION_IDS=4,5,6"
    end

    remover = PeopleRemover.new(
      person_ids: person_ids,
      form_submission_ids: submission_ids,
      delete_users: ENV["DELETE_USERS"] == "true",
      force: ENV["FORCE"] == "true"
    )

    puts "\n⚠️  WARNING: This permanently deletes each person and their ENTIRE data +"
    puts "    audit graph (and their User account where applicable). This cannot be"
    puts "    undone — verify every id against the dry-run output before re-running"
    puts "    with CONFIRM=true.\n"

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

    # Attribute the deletion to an admin actor so the Ahoy "destroy" audit records
    # who did it. Unlike the web flow there's no controller to flush the buffered
    # lifecycle events, so we flush them here on success.
    actor_email = ENV.fetch("ACTOR_EMAIL", "umberto.user@example.com")
    actor = User.where(email: actor_email).last
    puts "Warning: audit actor #{actor_email} not found — deletions won't be attributed." unless actor

    Current.user = actor
    Current.source = "rake:data:remove_people"
    begin
      deleted = remover.call
      flush_audit = -> {
        events = Analytics::LifecycleBuffer.store
        return if events.empty?
        tracker = Ahoy::Tracker.new(user: actor)
        events.each { |payload| tracker.track(payload[:name], payload[:properties]) }
        events.clear
      }
      flush_audit.call
      puts "\nDone. Deleted #{deleted.size} person(s) and their data + audit graph."
    rescue ActiveRecord::InvalidForeignKey => e
      abort "\nAborted (nothing deleted): a linked User Account owns content that " \
            "can't be orphaned (workshops, reports, stories, etc.). Reassign or " \
            "remove it first.\n#{e.message}"
    ensure
      Current.reset
    end
  end
end
