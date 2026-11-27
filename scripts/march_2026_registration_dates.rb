# One-off: the 10 people registered on both March 2026 events kept their #19
# registrations, which date from when #19 was built. Give those back the dates
# they signed up on #2, which their tickets show as "Registered on".
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/march_2026_registration_dates.rb
#   DRY_RUN=false bin/rails runner scripts/march_2026_registration_dates.rb

dry_run = ENV["DRY_RUN"] != "false"

registered_at = {
  777 => "2026-02-27 21:51:59", 994 => "2026-02-28 00:27:44", 817 => "2026-02-28 13:53:37",
  813 => "2026-03-01 02:40:43", 816 => "2026-03-01 17:49:03", 1268 => "2026-03-01 17:55:34",
  1269 => "2026-03-01 19:03:39", 815 => "2026-03-01 19:12:14", 1002 => "2026-03-01 20:05:17",
  1267 => "2026-03-01 20:13:37"
}.freeze

ActiveRecord::Base.transaction(requires_new: true) do
  registered_at.each do |id, utc|
    registration = EventRegistration.find_by!(id: id, event_id: 19)
    before = registration.created_at
    registration.update_columns(created_at: Time.find_zone("UTC").parse(utc))
    puts "##{id}: #{before.to_date} → #{registration.created_at.to_date}"
  end

  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "DRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "Done."
