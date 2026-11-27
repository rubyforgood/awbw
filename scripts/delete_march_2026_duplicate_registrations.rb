# One-off, one of three: delete the 10 March 2026 registrations on #2 whose people
# are also registered on the TAC261 event (#19), plus 4 staff asked to remove.
# None hold money, attendance or linked records worth keeping. Runs in any order with
# merge_march_2026_registrations.rb and march_2026_registration_dates.rb.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/delete_march_2026_duplicate_registrations.rb
#   DRY_RUN=false bin/rails runner scripts/delete_march_2026_duplicate_registrations.rb

dry_run = ENV["DRY_RUN"] != "false"

source = Event.find(2)

# The same people's #19 registrations: 777, 813, 815, 816, 817, 994, 1002, 1267, 1268, 1269.
duplicate_ids = [ 13, 64, 91, 77, 45, 32, 103, 106, 80, 88 ].freeze
# Test and no-longer-wanted registrations staff asked to remove.
removed_ids = [ 7, 11, 14, 15 ].freeze

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = "delete_march_2026_duplicate_registrations"

ActiveRecord::Base.transaction(requires_new: true) do
  { "duplicate" => duplicate_ids, "removed" => removed_ids }.each do |label, ids|
    deleted = source.event_registrations.where(id: ids).destroy_all
    puts "Deleted #{deleted.size} of #{ids.size} #{label} registrations on ##{source.id}"
  end

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "DRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "Done."
