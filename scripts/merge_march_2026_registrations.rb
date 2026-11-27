# One-off, part 2 of 2: move the March 2026 registrations from #2 onto the TAC261
# event that holds the money (#19). Run merge_march_2026_event_settings.rb first.
#
# 10 people are registered on both. Their #2 copies hold nothing #19's lack, so
# they're deleted, and #19's copies take over their emailed ticket links.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/merge_march_2026_registrations.rb
#   DRY_RUN=false bin/rails runner scripts/merge_march_2026_registrations.rb

dry_run = ENV["DRY_RUN"] != "false"

source = Event.find(2)
target = Event.find(19)

# Registration on #2 => the same person's registration on #19, which is kept.
duplicates = {
  13 => 777, 64 => 813, 91 => 815, 77 => 816, 45 => 817,
  32 => 994, 103 => 1002, 106 => 1267, 80 => 1268, 88 => 1269
}.freeze

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = "merge_march_2026_registrations"

ActiveRecord::Base.transaction(requires_new: true) do
  duplicates.each do |from_id, to_id|
    copy = EventRegistration.find_by!(id: from_id, event: source)
    kept = EventRegistration.find_by!(id: to_id, event: target)
    copy.destroy!
    kept.update!(slug: copy.slug)
  end
  puts "Deleted #{duplicates.size} duplicate registrations on ##{source.id}"

  moving = source.event_registrations.reload.to_a
  moving.each { |registration| registration.update!(event: target) }
  puts "Moved #{moving.size} registrations to ##{target.id}"
  moving.group_by(&:status).each { |status, group| puts "  #{status}: #{group.size}" }

  owing = target.event_registrations.reload.active.reject(&:paid_in_full?)
  puts "Now owing on ##{target.id}: #{owing.size} people, #{MoneyFormatter.dollars_from_cents(owing.sum(&:remaining_cost))}"

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "DRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "Done. Check ##{target.id}'s registrants, then delete ##{source.id}."
