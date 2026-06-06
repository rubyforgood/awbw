# WorkshopLog seeds (dev-only) - run on their own via `rake db:seed:workshop_logs`,
# or as part of `rake db:seed:dev`. Builds a realistic log history for Aisha plus a
# few admin logs; relies on workshops/organizations being present.

puts "Creating WorkshopLogs…"
aisha_user = User.find_by(email: "aisha.user@example.com")
aisha_org = aisha_user&.person&.affiliations&.first&.organization || Organization.first
all_workshops = Workshop.all.to_a.shuffle

if aisha_user && all_workshops.any? && WorkshopLog.where(created_by_id: aisha_user.id).none?
  # 30 logs for Aisha's primary workshop
  primary_workshop = all_workshops.shift
  30.times do |i|
    WorkshopLog.create!(
      workshop_id: primary_workshop.id,
      organization_id: aisha_org.id,
      windows_type_id: primary_workshop.windows_type_id || WindowsType.first.id,
      created_by_id: aisha_user.id,
      workshop_held_on: Date.today - (i * 7 + rand(0..3)).days,
      children_ongoing: rand(1..6),
      teens_ongoing: rand(0..4),
      adults_ongoing: rand(2..12),
      children_first_time: rand(0..3),
      teens_first_time: rand(0..2),
      adults_first_time: rand(0..5),
      created_at: Time.current - (i * 7).days,
      updated_at: Time.current - (i * 7).days
    )
  end

  # Up to 10 other workshops with varying log counts (1–15)
  other_workshops = all_workshops.first(10)
  log_counts = [ 15, 12, 9, 7, 5, 4, 3, 2, 1, 1 ]
  other_workshops.each_with_index do |workshop, idx|
    count = log_counts[idx] || 1
    count.times do |i|
      WorkshopLog.create!(
        workshop_id: workshop.id,
        organization_id: aisha_org.id,
        windows_type_id: workshop.windows_type_id || WindowsType.first.id,
        created_by_id: aisha_user.id,
        workshop_held_on: Date.today - (i * 14 + rand(0..6)).days,
        children_ongoing: rand(0..5),
        teens_ongoing: rand(0..3),
        adults_ongoing: rand(1..10),
        children_first_time: rand(0..2),
        teens_first_time: rand(0..2),
        adults_first_time: rand(0..4),
        created_at: Time.current - (i * 14).days,
        updated_at: Time.current - (i * 14).days
      )
    end
  end
  puts "  Created 89 logs for Aisha on 11 workshops"
end

# A few logs for the admin user as well
if WorkshopLog.where(created_by_id: User.first&.id).none?
  5.times do
    workshop = Workshop.all.sample
    next unless workshop

    WorkshopLog.create!(
      workshop_id: workshop.id,
      organization_id: Organization.all.sample&.id,
      windows_type_id: WindowsType.all.sample&.id,
      created_by_id: User.first&.id,
      workshop_held_on: Date.today - rand(1..90).days,
      children_ongoing: rand(0..5),
      teens_ongoing: rand(0..3),
      adults_ongoing: rand(0..10),
      children_first_time: rand(0..2),
      teens_first_time: rand(0..2),
      adults_first_time: rand(0..4),
      created_at: Time.current - rand(1..90).days,
      updated_at: Time.current - rand(1..40).days
    )
  end
end
