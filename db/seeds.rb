puts "Creating Users…"

# Helper: case-insensitive find-or-create by name
def find_or_create_by_name!(klass, name, **attrs, &block)
  record = klass.where("LOWER(name) = LOWER(?)", name).first
  return record if record

  record = klass.new(name: name, **attrs)
  block&.call(record)
  record.save!
  record
end

# Admin
admin = User.find_or_create_by!(email: "umberto.user@example.com") do |user|
  user.password = "password"
  user.super_user = true
  user.confirmed_at = Time.current
end

unless admin.person.present?
  person = Person.create!(
    first_name: "Umberto",
    last_name: "User",
    email: admin.email,
    created_by: admin,
    updated_by: admin,
    profile_is_searchable: true
  )
  admin.update!(person: person)
end


# Non-Admin
amy = User.find_or_create_by!(email: "amy.user@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end

unless amy.person.present?
  person = Person.create!(
    first_name: "Amy",
    last_name: "User",
    email: amy.email,
    created_by: amy,
    updated_by: amy,
    profile_is_searchable: true
  )
  amy.update!(person: person)
end

# Non-Admin 2
priya = User.find_or_create_by!(email: "priya.user@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end

unless priya.person.present?
  person = Person.create!(
    first_name: "Priya",
    last_name: "Sharma",
    email: priya.email,
    created_by: priya,
    updated_by: priya,
    profile_is_searchable: true
  )
  priya.update!(person: person)
end

# Orphaned
User.find_or_create_by!(email: "orphaned_reports@awbw.org") do |user|
  user.first_name = "Orphaned Reports"
  user.last_name = "User"
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end

# Invited but hasn't clicked the link yet
invited = User.find_or_create_by!(email: "invited.pending@example.com") do |user|
  user.password = "password"
  user.super_user = false
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
end.tap do |u|
  u.update_columns(confirmed_at: nil) unless u.welcome_instructions_sent_at.present?
end

# Invited, no person record
invited_no_person = User.find_or_create_by!(email: "invited.noperson@example.com") do |user|
  user.password = "password"
  user.super_user = false
end
unless invited_no_person.confirmed_at.present?
  invited_no_person.update_columns(
    confirmed_at: nil,
    welcome_instructions_token: Devise.friendly_token,
    welcome_instructions_created_at: 10.days.ago,
    welcome_instructions_sent_at: 10.days.ago
  )
end

# Only reset seed-user passwords, not every user in the database
seed_emails = %w[umberto.user@example.com amy.user@example.com priya.user@example.com orphaned_reports@awbw.org]
user_password = Devise::Encryptor.digest(User, "password")
User.where(email: seed_emails).update_all(encrypted_password: user_password)

puts "Creating WindowsTypes…"
adult_type = WindowsType.where(name: "ADULT WINDOWS")
                        .first_or_create!(legacy_id: 1, short_name: "ADULT")
childrens_type = WindowsType.where(name: "CHILDREN'S WINDOWS")
                            .first_or_create!(legacy_id: 2, short_name: "CHILDREN")
combined_type = WindowsType.where(name: "ADULT & CHILDREN COMBINED (FAMILY) WINDOWS")
                           .first_or_create!(legacy_id: 3, short_name: "COMBINED")

puts "Creating FormBuilders…"
FormBuilder.where(name: "Adult Monthly Report", windows_type: adult_type).first_or_create!(id: 4)
FormBuilder.where(name: "Adult Workshop Log", windows_type: adult_type).first_or_create!(id: 3)
FormBuilder.where(name: "Children's Monthly Report", windows_type: childrens_type).first_or_create!(id: 2)
FormBuilder.where(name: "Children's Workshop Log", windows_type: childrens_type).first_or_create!(id: 1)
FormBuilder.where(name: "Share a Story", windows_type: combined_type).first_or_create!(id: 7)
FormBuilder.where(name: "Family Workshop Log", windows_type: combined_type).first_or_create!(id: 5)

puts "Creating OrganizationStatuses…"
OrganizationStatus::ORGANIZATION_STATUSES.each do |status|
  OrganizationStatus.where(name: status).first_or_create!
end

puts "Creating Organization…"
awbw_org = Organization.find_or_create_by!(name: ENV.fetch("ORGANIZATION_NAME", "AWBW")) do |org|
  org.organization_status = OrganizationStatus.find_by!(name: "Active")
end

[ admin, amy, priya ].each do |user|
  next unless user.person.present? && user.person.affiliations.empty?

  Affiliation.create!(
    person: user.person,
    organization: awbw_org,
    position: :leader,
    start_date: 1.year.ago.to_date
  )
end

puts "Creating OrganizationObligations…"
OrganizationObligation::OBLIGATION_TYPES.each do |obligation_type|
  OrganizationObligation.where(name: obligation_type).first_or_create!
end

puts "Creating Sectors…"
Sector::SECTOR_TYPES.each do |sector_type|
  sector = find_or_create_by_name!(Sector, sector_type)
  sector.update!(published: true) unless sector.published?
end

puts "Creating CategoryTypes/Categories…"
category_type_categories = [
  [ "AgeRange", "3-5" ],
  [ "AgeRange", "6-12" ],
  [ "AgeRange", "13-17" ],
  [ "AgeRange", "18+" ],
  [ "AgeRange", "Mixed-age groups" ],
  [ "AgeRange", "Family windows" ],
  # ["ArtType", "Boxes", 1],
  [ "ArtType", "Clay", 11 ],
  [ "ArtType", "Collage", 2 ],
  [ "ArtType", "Coloring" ], # fake id
  [ "ArtType", "Cray-Pas (crayon, oil pastels)", 3 ],
  [ "ArtType", "Digital Media", 21 ],
  [ "ArtType", "Dolls", 10 ],
  [ "ArtType", "Drawing", 17 ],
  [ "ArtType", "Embodied Art", 20 ],
  [ "ArtType", "Jewelry", 13 ],
  [ "ArtType", "Journaling", 5 ],
  [ "ArtType", "Masks", 16 ],
  [ "ArtType", "Mixed-Media", 6 ],
  [ "ArtType", "Painting", 7 ],
  [ "ArtType", "Poetry/Creative Writing" ], # fake id
  [ "ArtType", "Puppets", 8 ],
  [ "ArtType", "Scratch Art", 18 ],
  [ "ArtType", "Sculpture", 9 ],
  [ "ArtType", "Shrinky Dinks", 12 ],
  [ "ArtType", "Touchstones" ], # fake id
  [ "ArtType", "Watercolor" ], # fake id

  [ "EmotionalTheme", "Communication" ],
  # ["EmotionalTheme", "D.V.", 10],
  # ["EmotionalTheme", "Dreams and Wishes", 2],
  [ "EmotionalTheme", "Discovering My Feelings", 1 ],
  [ "EmotionalTheme", "Empathy" ],
  [ "EmotionalTheme", "Gratitude" ],
  [ "EmotionalTheme", "Grief" ],
  [ "EmotionalTheme", "Handling Anger", 3 ],
  [ "EmotionalTheme", "Hopeful Future" ],
  # ["EmotionalTheme", "Leaving the Shelter", 4],
  [ "EmotionalTheme", "My Body", 5 ],
  [ "EmotionalTheme", "Relationships / Boundaries", 6 ],
  [ "EmotionalTheme", "Safety and Security", 7 ],
  [ "EmotionalTheme", "Self-Care", 9 ],
  [ "EmotionalTheme", "Self-Esteem", 11 ],
  [ "EmotionalTheme", "Self-Regulation" ],
  # ["EmotionalTheme", "Sexual Assault/Abuse", 13],
  [ "EmotionalTheme", "Spirituality", 12 ],
  [ "EmotionalTheme", "Transitions" ],
  [ "EmotionalTheme", "Who Am I?", 8 ],
  [ "Focus", "Adults and Children Together", 6 ],
  [ "Focus", "Collaboration and Mutuality" ],
  [ "Focus", "Community Engagement", 19 ],
  [ "Focus", "Cultural Issues" ],
  [ "Focus", "Dating Violence for Teens", 15 ],
  [ "Focus", "DV 101", 16 ],
  [ "Focus", "Easy Set-up", 1 ],
  [ "Focus", "Empowerment, Voice, and Choice" ],
  # ["Focus", "Exhibit Recommended", 10],
  [ "Focus", "Gender Issues" ],
  [ "Focus", "Good for Exhibits" ],
  [ "Focus", "Good for New Leaders", 3 ],
  [ "Focus", "Good for New Participants" ],
  [ "Focus", "Good for One-on-One Sessions", 2 ],
  # ["Focus", "Good for Working with Boys", 4],
  [ "Focus", "Good for Staff" ],
  [ "Focus", "Historical Trauma" ],
  [ "Focus", "Inexpensive Supplies", 5 ],
  # ["Focus", "Life Skills", 7],
  [ "Focus", "Movement and Body Awareness", 17 ],
  [ "Focus", "Peer Support" ],
  [ "Focus", "Resilience" ],
  [ "Focus", "Skill Building" ],
  [ "Focus", "Social Emotional Learning" ],
  [ "Focus", "Spanish Translation", 11 ],
  # ["Focus", "Staff Retreat", 9],
  # ["Focus", "Storytelling", 18],
  [ "Focus", "Team Building", 8 ],
  [ "Focus", "Transparency" ],
  [ "HolidayTheme", "Chanukah", 1 ],
  [ "HolidayTheme", "Child Abuse Prevention Month" ],
  [ "HolidayTheme", "Christmas", 2 ],
  [ "HolidayTheme", "Denim Day" ],
  [ "HolidayTheme", "DV Awareness Month", 9 ],
  [ "HolidayTheme", "Easter", 3 ],
  [ "HolidayTheme", "Father's Day", 12 ],
  # ["HolidayTheme", "Halloween", 4],
  [ "HolidayTheme", "Independence Day", 5 ],
  [ "HolidayTheme", "Mother's Day", 8 ],
  [ "HolidayTheme", "New Year", 7 ],
  [ "HolidayTheme", "Sexual Assault Awareness Month", 15 ],
  [ "HolidayTheme", "St. Patrick's Day", 14 ],
  [ "HolidayTheme", "Teen Dating Violence Awareness Month", 16 ],
  # ["HolidayTheme", "Thanksgiving", 11],
  [ "HolidayTheme", "Valentine's Day", 10 ]
  # ["Service Population", "Child Abuse"], # now a Sector
  # ["Service Population", "Domestic Violence"], # now a Sector
  # ["Service Population", "Education/Schools"], # now a Sector
  # ["Service Population", "LGBTQIA"], # now a Sector
  # ["Service Population", "Sexual Assault"], # now a Sector
  # ["Service Population", "Substance Abuse"], # now a Sector
  # ["Service Population", "Veterans & Military"], # now a Sector
]
category_type_categories.each do |category_type_name, category_name, _legacy_id|
  next if category_type_name.nil?

  ct = find_or_create_by_name!(CategoryType, category_type_name, published: true)
  ct.update!(published: true) unless ct.published?

  # Category names are globally unique, so look up globally first
  cat = Category.where("LOWER(name) = LOWER(?)", category_name).first
  if cat
    # Reassign to correct type if orphaned or misassigned
    cat.update!(category_type: ct) unless cat.category_type_id == ct.id
  else
    cat = ct.categories.create!(name: category_name, published: true)
  end
  cat.update!(published: true) unless cat.published?
end

puts "Setting AgeRange category positions…"
age_range_order = ["3-5", "6-12", "13-17", "18+", "Mixed-age groups", "Family windows"]
age_range_order.each_with_index do |name, i|
  Category.where("LOWER(name) = LOWER(?)", name).update_all(position: i + 1)
end

puts "Creating StoryPopulation CategoryType…"
story_population_type = find_or_create_by_name!(CategoryType, "StoryPopulation") do |ct|
  ct.display_text = "Who is this story about?"
  ct.story_specific = true
  ct.published = true
end
story_population_type.update!(display_text: "Who is this story about?", story_specific: true, published: true)

%w[Adults Children Colleagues Community Families Self Teens].each do |name|
  cat = Category.where("LOWER(name) = LOWER(?)", name).first
  if cat
    cat.update!(category_type: story_population_type) unless cat.category_type_id == story_population_type.id
  else
    cat = story_population_type.categories.create!(name: name, published: true)
  end
  cat.update!(published: true) unless cat.published?
end

puts "Creating WorkshopEnvironment CategoryType…"
workshop_env_type = find_or_create_by_name!(CategoryType, "WorkshopEnvironment") do |ct|
  ct.display_text = "Workshop Environments"
  ct.story_specific = false
  ct.profile_specific = true
  ct.published = true
end
workshop_env_type.update!(display_text: "Workshop Environments", story_specific: false, profile_specific: true, published: true)

%w[Shelter School Hospital Community\ Center After-School\ Program Virtual/Online Private\ Practice Other].each do |name|
  cat = Category.where("LOWER(name) = LOWER(?)", name).first
  if cat
    cat.update!(category_type: workshop_env_type) unless cat.category_type_id == workshop_env_type.id
  else
    cat = workshop_env_type.categories.create!(name: name, published: true)
  end
  cat.update!(published: true) unless cat.published?
end

puts "Creating standalone registration forms…"
unless Form.standalone.exists?(name: ShortEventRegistrationFormBuilder::FORM_NAME)
  ShortEventRegistrationFormBuilder.build_standalone!
end

unless Form.standalone.exists?(name: ExtendedEventRegistrationFormBuilder::FORM_NAME)
  ExtendedEventRegistrationFormBuilder.build_standalone!
end

unless Form.standalone.exists?(name: ScholarshipApplicationFormBuilder::FORM_NAME)
  ScholarshipApplicationFormBuilder.build_standalone!
end
