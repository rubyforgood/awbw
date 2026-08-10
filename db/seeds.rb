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

puts "Creating legacy scholarship Grants…"
# Named legacy scholarship funds. Story-import rows tagged "Cathy scholarship" /
# "babs mayer" connect to these via the recipient's Scholarship (grant → scholarship
# → recipient, who is the story author). Funded by AWBW; change the funder if a
# legacy fund is attributed to an individual donor instead.
[ "Cathy Salser Legacy Scholarship", "Babs Mayer Legacy Scholarship" ].each do |grant_name|
  Grant.find_or_create_by!(name: grant_name) do |grant|
    grant.funder = awbw_org
    grant.amount_cents = 0
  end
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

# Feature a few sectors in the Story Share portal (nav + landing rows, ordered).
# Admins can change these from the Sectors admin.
{ "Domestic Violence" => 1, "Self-Care/Personal Growth" => 2, "Racial/Social Justice" => 3 }.each do |name, position|
  Sector.find_by(name: name)&.update!(story_share_position: position)
end

puts "Creating CategoryTypes/Categories…"
category_type_categories = [
  # AgeRange is reconciled separately below (clean names + description ranges).
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

# Bulk-reconcile display positions to match the production portal, bypassing the
# positioning gem (as the workshop-settings block does) so exact numbers — gaps
# and all — stick. Parks everything high first to dodge the unique
# [category_type_id, position] index mid-reconcile.
set_category_positions = ->(category_type, positions) do
  category_type.categories.order(:id).each_with_index do |cat, i|
    cat.update_columns(position: 100_000 + i)
  end
  positions.each do |name, position|
    category_type.categories.where("LOWER(name) = LOWER(?)", name).first&.update_columns(position: position)
  end
end

# Categories kept in the seeds for their history but no longer offered — flipped
# to unpublished (taggings preserved) so the published set matches the production portal.
unpublished_categories = {
  "ArtType" => [ "Coloring", "Poetry/Creative Writing", "Touchstones", "Watercolor" ],
  "EmotionalTheme" => [ "Gratitude", "Self-Regulation" ],
  "Focus" => [ "Collaboration and Mutuality", "Cultural Issues", "Empowerment, Voice, and Choice",
               "Gender Issues", "Historical Trauma", "Peer Support", "Transparency" ]
}
unpublished_categories.each do |type_name, names|
  ct = CategoryType.find_by(name: type_name)
  next unless ct
  ct.categories.where("LOWER(name) IN (?)", names.map(&:downcase)).find_each { |cat| cat.update!(published: false) }
end

# Display order for the published topic categories, matching the production portal.
{
  "ArtType" => [ [ "Clay", 1 ], [ "Collage", 2 ], [ "Cray-Pas (crayon, oil pastels)", 4 ], [ "Digital Media", 5 ],
                 [ "Dolls", 6 ], [ "Drawing", 7 ], [ "Embodied Art", 8 ], [ "Jewelry", 9 ], [ "Journaling", 10 ],
                 [ "Masks", 11 ], [ "Mixed-Media", 12 ], [ "Painting", 13 ], [ "Puppets", 15 ], [ "Scratch Art", 16 ],
                 [ "Sculpture", 17 ], [ "Shrinky Dinks", 18 ] ],
  "EmotionalTheme" => [ [ "Communication", 1 ], [ "Discovering My Feelings", 2 ], [ "Empathy", 3 ], [ "Grief", 5 ],
                        [ "Handling Anger", 6 ], [ "Hopeful Future", 7 ], [ "My Body", 8 ],
                        [ "Relationships / Boundaries", 9 ], [ "Safety and Security", 10 ], [ "Self-Care", 11 ],
                        [ "Self-Esteem", 12 ], [ "Spirituality", 14 ], [ "Transitions", 15 ], [ "Who Am I?", 16 ] ],
  "HolidayTheme" => [ [ "Chanukah", 1 ], [ "Child Abuse Prevention Month", 2 ], [ "Christmas", 3 ], [ "Denim Day", 4 ],
                      [ "DV Awareness Month", 5 ], [ "Easter", 6 ], [ "Father's Day", 7 ], [ "Independence Day", 8 ],
                      [ "Mother's Day", 9 ], [ "New Year", 10 ], [ "Sexual Assault Awareness Month", 11 ],
                      [ "St. Patrick's Day", 12 ], [ "Teen Dating Violence Awareness Month", 13 ], [ "Valentine's Day", 14 ] ],
  "Focus" => [ [ "Adults and Children Together", 1 ], [ "Community Engagement", 3 ], [ "Dating Violence for Teens", 5 ],
               [ "DV 101", 6 ], [ "Easy Set-up", 7 ], [ "Good for Exhibits", 10 ], [ "Good for New Leaders", 11 ],
               [ "Good for New Participants", 12 ], [ "Good for One-on-One Sessions", 13 ], [ "Good for Staff", 14 ],
               [ "Inexpensive Supplies", 16 ], [ "Movement and Body Awareness", 17 ], [ "Resilience", 19 ],
               [ "Skill Building", 20 ], [ "Social Emotional Learning", 21 ], [ "Spanish Translation", 22 ],
               [ "Team Building", 23 ] ]
}.each do |type_name, positions|
  ct = CategoryType.find_by(name: type_name)
  set_category_positions.(ct, positions) if ct
end

# --- StoryPopulation (reconciled BEFORE AgeRange) --------------------------
# The age twins carry a trailing underscore so the clean names are free for
# AgeRange (Category names are globally unique). Run before AgeRange so renaming
# AgeRange to "Children"/"Teens"/"Adults" doesn't collide with these.
puts "Creating StoryPopulation CategoryType…"
story_population_type = find_or_create_by_name!(CategoryType, "StoryPopulation") do |ct|
  ct.display_text = "Who is this story about?"
  ct.story_specific = true
  ct.published = true
end
story_population_type.update!(display_text: "Who is this story about?", story_specific: true, published: true)

# [ target name, legacy clean name, position ]. The underscore names match the
# earlier clean form so a pre-rename category is renamed in place, not duplicated.
story_populations = [
  [ "Colleagues", "Colleagues", 1 ],
  [ "Community", "Community", 2 ],
  [ "Self", "Self", 3 ],
  [ "Teens_", "Teens", 4 ],
  [ "Children_", "Children", 5 ],
  [ "Adults_", "Adults", 6 ],
  [ "Families", "Families", 7 ]
]
story_populations.each do |name, legacy, _position|
  cat = story_population_type.categories.where("LOWER(name) = LOWER(?)", name).first ||
        story_population_type.categories.where("LOWER(name) = LOWER(?)", legacy).first ||
        story_population_type.categories.create!(name: name)
  cat.update!(name: name, published: true)
end
set_category_positions.(story_population_type, story_populations.map { |name, _, position| [ name, position ] })

# --- AgeRange --------------------------------------------------------------
# Clean names with the range moved into the description column (matching the
# production portal). Match the clean name or the earlier "Name (range)" form so a
# category seeded before the split is renamed in place — preserving taggings.
puts "Reconciling AgeRange categories…"
age_range_type = find_or_create_by_name!(CategoryType, "AgeRange", published: true)
age_range_type.update!(published: true) unless age_range_type.published?

# [ clean name, description, position ]
age_ranges = [
  [ "Children", "0-12", 1 ],
  [ "Teens", "13-17", 2 ],
  [ "Adults", "18+", 3 ],
  [ "Elders", "65+", 6 ]
]
age_ranges.each do |name, description, _position|
  cat = age_range_type.categories.where("LOWER(name) = LOWER(?)", name).first ||
        age_range_type.categories.where("LOWER(name) LIKE LOWER(?)", "#{name} (%").first ||
        age_range_type.categories.create!(name: name)
  cat.update!(name: name, published: true, description: description)
end

# Unpublish any AgeRange no longer on the canonical list (retired 3-5 / 6-12 /
# Family windows buckets), preserving taggings.
canonical_age_names = age_ranges.map { |name, _, _| name.downcase }
age_range_type.categories.reject { |cat| canonical_age_names.include?(cat.name.downcase) }
  .each { |cat| cat.update!(published: false) }
set_category_positions.(age_range_type, age_ranges.map { |name, _, position| [ name, position ] })

# Order the Story Share audience nav. The age groups resolve to the clean-named
# AgeRange categories; the rest to their StoryPopulation categories.
%w[Children Teens Adults Families Community Self Colleagues].each_with_index do |name, index|
  Category.where("LOWER(name) = LOWER(?)", name).first&.update!(story_share_position: index + 1)
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
