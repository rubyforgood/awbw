# One-off, part 1 of 2: move the March 2026 registrations from #2 onto the TAC261
# event that holds the money (#19). The other part,
# merge_march_2026_event_settings.rb, carries #2's page and ticket settings over;
# run that one first, then this one.
#
# No allocation moves: #19's registrations keep their own, and #2's have none.
# Registrations for someone already on #19 merge into theirs; the rest move.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/merge_march_2026_registrations.rb
#   DRY_RUN=false bin/rails runner scripts/merge_march_2026_registrations.rb
#
# First merge people 2811 and 36284 in the people deduper.

dry_run = ENV["DRY_RUN"] != "false"

source = Event.find(2)
target = Event.find(19)

# Registration on #2 => the same person's registration on #19, which is kept.
merges = {
  13 => 777, 64 => 813, 91 => 815, 77 => 816, 45 => 817,
  32 => 994, 103 => 1002, 106 => 1267, 80 => 1268, 88 => 1269
}.freeze

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = "merge_march_2026_registrations"

problems = []
merges.each do |from_id, to_id|
  from = EventRegistration.find_by(id: from_id, event: source)
  to = EventRegistration.find_by(id: to_id, event: target)
  if from.nil? || to.nil?
    problems << "pair #{from_id} → #{to_id} not found on the expected events"
  elsif from.registrant_id != to.registrant_id
    problems << "pair #{from_id} → #{to_id}: merge people ##{from.registrant_id} and ##{to.registrant_id} first"
  end
end
if problems.any?
  puts "Stopped — nothing written:", problems.map { |problem| "  - #{problem}" }
  abort
end

ActiveRecord::Base.transaction(requires_new: true) do
  deduper = ModelDeduper.new(model_class: EventRegistration, logger: Rails.logger, dry_run: false)

  merges.each do |from_id, to_id|
    from = EventRegistration.find(from_id)
    to = EventRegistration.find(to_id)
    # #2's ticket link and registration date are the ones people know.
    slug = from.slug
    created_at = from.created_at

    deduper.merge(to, from)
    to.update!(slug: slug)
    to.update_columns(created_at: created_at)
    puts "Merged ##{from_id} into ##{to_id}"
  end

  moving = source.event_registrations.reload.to_a
  moving.each { |registration| registration.update!(event: target) }
  puts "Moved #{moving.size} registrations to ##{target.id}"

  owing = target.event_registrations.reload.active.reject(&:paid_in_full?)
  puts "Now owing on ##{target.id}: #{owing.size} people, #{MoneyFormatter.dollars_from_cents(owing.sum(&:remaining_cost))}"

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "DRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "Done. Check ##{target.id}'s registrants."
