# Dev-only user variations - run on their own via `rake db:seed:users`, or as
# part of `rake db:seed:dev`. These exercise login/invite/lock edge cases and
# must never run in production, so they live here rather than in `db/seeds.rb`
# (which seeds only the required base users: Umberto, Amy, Aisha, Orphaned).

puts "Seeding dev user variations (invite/lock/confirmation states)…"

# created_by/updated_by point at the base admin, seeded by `db:seed` first.
admin = User.find_by!(email: "umberto.user@example.com")

# Invited but hasn't clicked the link yet
invited = User.find_or_create_by!(email: "invited.pending@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end
unless invited.confirmed_at.present?
  invited.update_columns(
    confirmed_at: nil,
    welcome_instructions_token: Devise.friendly_token,
    welcome_instructions_created_at: 3.days.ago,
    welcome_instructions_sent_at: 3.days.ago
  )
end
unless invited.person.present?
  person = Person.create!(
    first_name: "Invited",
    last_name: "Pending",
    email: invited.email,
    created_by: admin,
    updated_by: admin,
    profile_is_searchable: true
  )
  invited.update!(person: person)
end

# Clicked confirmation link but didn't set password
confirmed_no_pw = User.find_or_create_by!(email: "confirmed.nopassword@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end
unless confirmed_no_pw.welcome_instructions_token.present?
  token = Devise.friendly_token
  confirmed_no_pw.update_columns(
    confirmed_at: 2.days.ago,
    welcome_instructions_token: token,
    welcome_instructions_created_at: 5.days.ago,
    welcome_instructions_sent_at: 5.days.ago
  )
end
unless confirmed_no_pw.person.present?
  person = Person.create!(
    first_name: "Confirmed",
    last_name: "NoPassword",
    email: confirmed_no_pw.email,
    created_by: admin,
    updated_by: admin,
    profile_is_searchable: true
  )
  confirmed_no_pw.update!(person: person)
end

# Locked account (too many failed attempts)
locked = User.find_or_create_by!(email: "locked.user@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = 1.month.ago
end
unless locked.locked_at.present?
  locked.update_columns(
    locked_at: 1.day.ago,
    failed_attempts: Devise.maximum_attempts
  )
end
unless locked.person.present?
  person = Person.create!(
    first_name: "Locked",
    last_name: "User",
    email: locked.email,
    created_by: admin,
    updated_by: admin,
    profile_is_searchable: true
  )
  locked.update!(person: person)
end

# Never invited (created but no confirmation sent)
never_invited = User.find_or_create_by!(email: "never.invited@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end
unless never_invited.welcome_instructions_sent_at.present?
  never_invited.update_columns(confirmed_at: nil)
end
unless never_invited.person.present?
  person = Person.create!(
    first_name: "Never",
    last_name: "Invited",
    email: never_invited.email,
    created_by: admin,
    updated_by: admin,
    profile_is_searchable: true
  )
  never_invited.update!(person: person)
end

# Invited a while ago, never clicked (stale invite)
stale_invited = User.find_or_create_by!(email: "stale.invite@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end
unless stale_invited.confirmed_at.present?
  stale_invited.update_columns(
    confirmed_at: nil,
    welcome_instructions_token: Devise.friendly_token,
    welcome_instructions_created_at: 45.days.ago,
    welcome_instructions_sent_at: 45.days.ago
  )
end
unless stale_invited.person.present?
  person = Person.create!(
    first_name: "Stale",
    last_name: "Invite",
    email: stale_invited.email,
    created_by: admin,
    updated_by: admin,
    profile_is_searchable: true
  )
  stale_invited.update!(person: person)
end

# Invited yesterday
recent_invited = User.find_or_create_by!(email: "recent.invite@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end
unless recent_invited.confirmed_at.present?
  recent_invited.update_columns(
    confirmed_at: nil,
    welcome_instructions_token: Devise.friendly_token,
    welcome_instructions_created_at: 1.day.ago,
    welcome_instructions_sent_at: 1.day.ago
  )
end
unless recent_invited.person.present?
  person = Person.create!(
    first_name: "Recent",
    last_name: "Invite",
    email: recent_invited.email,
    created_by: admin,
    updated_by: admin,
    profile_is_searchable: true
  )
  recent_invited.update!(person: person)
end

# Never invited, no person record either
User.find_or_create_by!(email: "orphan.uninvited@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end.tap do |u|
  u.update_columns(confirmed_at: nil) unless u.welcome_instructions_sent_at.present?
end

# Invited, no person record
invited_no_person = User.find_or_create_by!(email: "invited.noperson@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end
unless invited_no_person.confirmed_at.present?
  invited_no_person.update_columns(
    confirmed_at: nil,
    welcome_instructions_token: Devise.friendly_token,
    welcome_instructions_created_at: 10.days.ago,
    welcome_instructions_sent_at: 10.days.ago
  )
end

# Reset only these dev users' passwords (mirrors the base seed reset), so they
# stay loggable-in after a reseed without touching any other user.
dev_user_emails = %w[
  invited.pending@example.com
  confirmed.nopassword@example.com
  locked.user@example.com
  never.invited@example.com
  stale.invite@example.com
  recent.invite@example.com
  orphan.uninvited@example.com
  invited.noperson@example.com
]
dev_user_password = Devise::Encryptor.digest(User, "password")
User.where(email: dev_user_emails).update_all(encrypted_password: dev_user_password)
