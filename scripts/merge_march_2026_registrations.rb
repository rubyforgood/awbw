# One-off, part 2 of 2: move the March 2026 registrations from #2 onto the TAC261
# event that holds the money (#19). Run merge_march_2026_event_settings.rb first.
#
# 10 people are registered on both. Their #2 copies hold nothing #19's lack, so
# they're deleted.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/merge_march_2026_registrations.rb
#   DRY_RUN=false bin/rails runner scripts/merge_march_2026_registrations.rb

dry_run = ENV["DRY_RUN"] != "false"

source = Event.find(2)
target = Event.find(19)

# #2 registrations whose person also has one on #19 (777, 813, 815, 816, 817, 994, 1002, 1267, 1268, 1269).
duplicate_ids = [ 13, 64, 91, 77, 45, 32, 103, 106, 80, 88 ].freeze

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = "merge_march_2026_registrations"

ActiveRecord::Base.transaction(requires_new: true) do
  deleted = source.event_registrations.where(id: duplicate_ids).destroy_all
  raise "only #{deleted.size} of #{duplicate_ids.size} duplicates are on ##{source.id}" if deleted.size != duplicate_ids.size
  puts "Deleted #{deleted.size} duplicate registrations on ##{source.id}"

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
