# Disable email delivery during seeding
ActionMailer::Base.perform_deliveries = false

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
aisha = User.find_or_create_by!(email: "aisha.user@example.com") do |user|
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end

unless aisha.person.present?
  person = Person.create!(
    first_name: "Aisha",
    last_name: "Sharma",
    email: aisha.email,
    created_by: aisha,
    updated_by: aisha,
    profile_is_searchable: true,
    profile_show_workshop_logs: true
  )
  aisha.update!(person: person)
end

# Orphaned
User.find_or_create_by!(email: "orphaned_reports@awbw.org") do |user|
  user.first_name = "Orphaned Reports"
  user.last_name = "User"
  user.password = "password"
  user.super_user = false
  user.confirmed_at = Time.current
end

# Dev-only user variations (invite/lock/confirmation edge cases) live in
# db/seeds/dev/users.rb and run via `rake db:seed:users` / `db:seed:dev`.

# Only reset seed-user passwords, not every user in the database
seed_emails = %w[umberto.user@example.com amy.user@example.com aisha.user@example.com orphaned_reports@awbw.org]
user_password = Devise::Encryptor.digest(User, "password")
User.where(email: seed_emails).update_all(encrypted_password: user_password)

puts "Creating WindowsTypes…"
adult_type = WindowsType.where(name: "Adult")
                        .first_or_create!(legacy_id: 1, short_name: "Adult")
childrens_type = WindowsType.where(name: "Children")
                            .first_or_create!(legacy_id: 2, short_name: "Children")
combined_type = WindowsType.where(name: "Combined")
                           .first_or_create!(legacy_id: 3, short_name: "Combined")

puts "Creating FormBuilders…"
# Keyed on the fixed id (the app references these ids), reconciling name and
# windows_type on every run so reseeding survives WindowsType records being
# recreated (e.g. after a name change).
form_builders = {
  4 => [ "Adult Monthly Report", adult_type ],
  3 => [ "Adult Workshop Log", adult_type ],
  2 => [ "Children's Monthly Report", childrens_type ],
  1 => [ "Children's Workshop Log", childrens_type ],
  7 => [ "Share a Story", combined_type ],
  5 => [ "Family Workshop Log", combined_type ]
}
form_builders.each do |id, (name, windows_type)|
  FormBuilder.find_or_initialize_by(id: id).update!(name: name, windows_type: windows_type)
end

# Prune duplicate canonical form builders left by older seed versions that
# created this set at auto-increment ids. Only exact name duplicates outside the
# pinned ids with no dependent forms are removed, so form-bearing records (prod
# builders are seeded via migrations and own forms) are never touched.
FormBuilder.where(name: form_builders.values.map(&:first))
           .where.not(id: form_builders.keys)
           .each { |duplicate| duplicate.destroy! if duplicate.forms.empty? }

puts "Creating OrganizationStatuses…"
OrganizationStatus::ORGANIZATION_STATUSES.each do |status|
  OrganizationStatus.where(name: status).first_or_create!
end

puts "Creating TopicSubscriptionTypes…"
TopicSubscriptionType::CANONICAL.each do |key, attrs|
  TopicSubscriptionType.where(key: key).first_or_create!(name: attrs[:name], event_selector: attrs[:event_selector])
end

puts "Creating Organization…"
awbw_org = Organization.find_or_create_by!(name: ENV.fetch("ORGANIZATION_NAME", "AWBW")) do |org|
  org.organization_status = OrganizationStatus.find_by!(name: "Active")
end

[ admin, amy, aisha ].each do |user|
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
# Optional descriptions clarify a sector on the public registration form: shown as
# subtext under the checkbox in the additional sectors list, and folded into
# the "Name (description)" label in the single primary sector dropdown (which
# can't show subtext). They come from the parenthetical clarifications on the
# canonical sector list. Names without an entry below have no description. Admins
# can edit each from the Sectors admin once seeded.
sector_descriptions = {
  "Climate/Environmental" => "fire recovery, disaster response, environmental trauma",
  "Community Building" => "grassroots, outreach and engagement",
  "Community Violence" => "gang violence, police violence, mass shootings",
  "Health/Medical" => "hospitals, illness/chronic disease",
  "Immigration" => "family separation, deportation, refugees/asylees",
  "Incarceration" => "including re-entry",
  "Reproductive Services" => "birth trauma, perinatal care, challenges conceiving, etc.",
  "Restorative/Transformative Justice" => "individual and community reconciliation",
  "Staff/Organizational Development" => "including secondary/vicarious trauma",
  "Systems/Policy Change" => "advocating at state/government levels for policy change"
}
Sector::SECTOR_TYPES.each do |sector_type|
  sector = find_or_create_by_name!(Sector, sector_type)
  sector.update!(published: true, description: sector_descriptions[sector_type])
end

# Unpublish any sector no longer on the canonical list, preserving its historical
# taggings rather than destroying them. SECTOR_TYPES already includes the "Other"
# catch-all, so it stays published.
canonical_names = Sector::SECTOR_TYPES.map(&:downcase)
Sector.all.reject { |sector| canonical_names.include?(sector.name.downcase) }
  .each { |sector| sector.update!(published: false) }

puts "Creating CategoryTypes/Categories…"
category_type_categories = [
  [ "AgeRange", "Children (0-12)" ],
  [ "AgeRange", "Teens (13-17)" ],
  [ "AgeRange", "Adults (18+)" ],
  [ "AgeRange", "Elders (65+)" ],
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

# Unpublish any AgeRange category no longer on the canonical list (e.g. the
# retired "3-5" / "6-12" / "Family windows" buckets), preserving historical
# taggings rather than destroying them, so the public form's age dropdowns only
# offer the current ranges. Scoped to AgeRange so other category types are untouched.
canonical_age_ranges = category_type_categories
  .select { |type_name, _name| type_name == "AgeRange" }
  .map { |_type_name, name| name.downcase }
age_range_type = CategoryType.find_by(name: "AgeRange")
age_range_type&.categories&.reject { |category| canonical_age_ranges.include?(category.name.downcase) }
  &.each { |category| category.update!(published: false) }

puts "Setting AgeRange category positions…"
Category.heal_position_column!

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
workshop_settings_type = find_or_create_by_name!(CategoryType, "WorkshopEnvironment") do |ct|
  ct.display_text = "Workshop Settings"
  ct.story_specific = false
  ct.profile_specific = true
  ct.published = true
end
workshop_settings_type.update!(display_text: "Workshop Settings", story_specific: false, profile_specific: true, published: true)

# Canonical workshop settings, in display order. The parenthetical examples from
# the registration form live in each option's description, shown as subtext under
# the option so the label stays a clean, clickable phrase. Obvious settings have
# no description. Admins can rename, re-describe, reorder, and publish/unpublish
# each from the Categories admin once seeded.
workshop_settings = [
  [ "Clinical setting", "Community mental health, outpatient, etc" ],
  [ "Educational setting", "Schools, universities, etc" ],
  [ "Events and conferences", nil ],
  [ "Faith-based setting", nil ],
  [ "Home visits", nil ],
  [ "Hospitals", nil ],
  [ "Law enforcement/court/legal", nil ],
  [ "Outreach program", "Drop-in services, support groups, etc" ],
  [ "Prisons/jails", nil ],
  [ "Private practice", nil ],
  [ "Residential program", "Emergency shelters, inpatient, etc" ],
  [ "Virtually", nil ],
  [ "With staff", nil ],
  [ "Other", "Please specify below." ]
]

# Park existing positions above the canonical range so we can renumber 1..N without
# tripping the unique [category_type_id, position] index mid-reconcile.
workshop_settings_type.categories.order(:id).each_with_index do |cat, i|
  cat.update_columns(position: 10_000 + i)
end

workshop_settings.each_with_index do |(name, description), index|
  # Match the clean name, or the earlier "Name (examples)" form that baked the
  # examples into the label, so a category seeded before descriptions moved into
  # their own column is renamed in place — preserving its taggings — rather than
  # duplicated and left orphaned.
  cat = workshop_settings_type.categories.where("LOWER(name) = LOWER(?)", name).first ||
        workshop_settings_type.categories.where("LOWER(name) LIKE LOWER(?)", "#{name} (%").first
  cat ||= workshop_settings_type.categories.create!(name: name)
  cat.update!(name: name, published: true, description: description)
  cat.update_columns(position: index + 1)
end

# Hide settings that are no longer offered without destroying historical taggings.
canonical_names = workshop_settings.map { |name, _| name.downcase }
workshop_settings_type.categories
  .reject { |cat| canonical_names.include?(cat.name.downcase) }
  .each { |cat| cat.update!(published: false) }
