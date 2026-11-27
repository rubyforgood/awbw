# One-off, one of three: move the March 2026 registrations from #2 onto the TAC261
# event that holds the money (#19). Runs in any order with
# merge_march_2026_event_settings.rb and delete_march_2026_duplicate_registrations.rb,
# which deletes #2's copies of the 10 people registered on both and 4 staff asked to remove.
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
# Test and no-longer-wanted registrations staff asked to remove.
removed_ids = [ 7, 11, 14, 15 ].freeze

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = "merge_march_2026_registrations"

ActiveRecord::Base.transaction(requires_new: true) do
  moving = source.event_registrations.where.not(id: duplicate_ids + removed_ids).to_a
  moving.each { |registration| registration.update!(event: target) }
  puts "Moved #{moving.size} registrations to ##{target.id}"

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "DRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "Done. Check ##{target.id}'s registrants."
