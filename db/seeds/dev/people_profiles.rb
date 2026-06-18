# People profile seeds (dev-only) - run on their own via `rake db:seed:people_profiles`,
# or as part of `rake db:seed:dev`. Creates Person records for the seed users, a set of
# search-disambiguation test people, their affiliations, and addresses/sectors.

puts "Creating Persons and Affiliations for seed users…"
[
  User.find_by(email: "umberto.user@example.com"),
  User.find_by(email: "amy.user@example.com"),
  User.find_by(email: "aisha.user@example.com")
].compact.each do |user|
  next if user.person.present?

  person = Person.create!(
    first_name: user.first_name,
    last_name: user.last_name,
    email: user.email,
    created_by: user,
    updated_by: user,
    profile_is_searchable: true
  )
  user.update!(person: person)

  org = Organization.all.sample
  next unless org

  Affiliation.create!(
    person: person,
    organization: org,
    position: :leader,
    start_date: 1.year.ago.to_date
  )
end

puts "Creating People…"
admin_user = User.find_by(email: "umberto.user@example.com")
orgs = Organization.all.to_a

test_people = [
  # --- Johnson cluster (8 people, similar last names) ---
  { first_name: "Maria", last_name: "Johnson", email: "maria.johnson@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Maria", last_name: "Johnston", email: "maria.johnston@yahoo.com", email_2: "mj@work.org", searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Marie", last_name: "Johnson", email: "marie.j@outlook.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },
  { first_name: "Mario", last_name: "Johnson", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Mark", last_name: "Johnson", email: "mark.johnson@hotmail.com", email_2: nil, searchable: false, with_user: true, affiliations: 1 },
  { first_name: "Mary", last_name: "Johnson", email: nil, email_2: "mary.j@backup.org", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Mariana", last_name: "Johnson", email: "mariana@johnson.com", email_2: nil, searchable: true, with_user: true, affiliations: 3 },
  { first_name: "Marcus", last_name: "Johnstone", email: "marcus.j@example.com", email_2: nil, searchable: true, with_user: false, affiliations: 1 },

  # --- Garcia cluster (7 people) ---
  { first_name: "Ana", last_name: "Garcia", email: "ana.garcia@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Anna", last_name: "Garcia", email: "anna.garcia@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Ana Maria", last_name: "Garcia", email: nil, email_2: "anamaria@personal.net", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Andrea", last_name: "Garcia", email: "andrea.g@outlook.com", email_2: nil, searchable: false, with_user: true, affiliations: 1 },
  { first_name: "Angel", last_name: "Garcia", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Ana", last_name: "Garcia-Lopez", email: "ana.gl@work.org", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Antonio", last_name: "Garcia", email: "antonio.garcia@gmail.com", email_2: "tony.g@backup.com", searchable: true, with_user: false, affiliations: 0 },

  # --- Smith cluster (7 people) ---
  { first_name: "Sarah", last_name: "Smith", email: "sarah.smith@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Sara", last_name: "Smith", email: "sara.smith@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },
  { first_name: "Samuel", last_name: "Smith", email: nil, email_2: "sam.smith@backup.org", searchable: true, with_user: false, affiliations: 2 },
  { first_name: "Sandra", last_name: "Smith", email: "sandra.s@outlook.com", email_2: nil, searchable: false, with_user: true, affiliations: 1 },
  { first_name: "Sarah", last_name: "Smithson", email: "sarah.smithson@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Sarah Jane", last_name: "Smith", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Santiago", last_name: "Smith", email: "santiago.smith@hotmail.com", email_2: "santi@alt.org", searchable: true, with_user: true, affiliations: 0 },

  # --- Williams cluster (6 people) ---
  { first_name: "Lisa", last_name: "Williams", email: "lisa.williams@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Lisa", last_name: "Williamson", email: "lisa.williamson@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Linda", last_name: "Williams", email: nil, email_2: "linda.w@backup.com", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Luis", last_name: "Williams", email: "luis.w@outlook.com", email_2: nil, searchable: false, with_user: false, affiliations: 1 },
  { first_name: "Lily", last_name: "Williams", email: "lily.williams@hotmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Lisa Marie", last_name: "Williams", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 0 },

  # --- Brown cluster (6 people) ---
  { first_name: "Jessica", last_name: "Brown", email: "jessica.brown@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Jennifer", last_name: "Brown", email: "jennifer.b@yahoo.com", email_2: "jen.brown@alt.org", searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Jessica", last_name: "Browning", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Jesse", last_name: "Brown", email: "jesse.brown@outlook.com", email_2: nil, searchable: false, with_user: true, affiliations: 0 },
  { first_name: "Jenna", last_name: "Brown", email: nil, email_2: "jenna.b@backup.net", searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Jean", last_name: "Brown", email: "jean.brown@hotmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },

  # --- Davis cluster (5 people) ---
  { first_name: "Kim", last_name: "Davis", email: "kim.davis@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Kimberly", last_name: "Davis", email: "kimberly.d@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },
  { first_name: "Kim", last_name: "Davidson", email: nil, email_2: "kim.dav@backup.org", searchable: true, with_user: false, affiliations: 2 },
  { first_name: "Karen", last_name: "Davis", email: "karen.davis@outlook.com", email_2: nil, searchable: false, with_user: true, affiliations: 1 },
  { first_name: "Katherine", last_name: "Davis", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },

  # --- De La Cruz cluster (5 people, spaces in last name) ---
  { first_name: "Rosa", last_name: "De La Cruz", email: "rosa.dlc@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Rosalia", last_name: "De La Cruz", email: nil, email_2: "rosalia@backup.net", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Rosa Maria", last_name: "De La Cruz", email: "rosamaria.dlc@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Roberto", last_name: "De La Cruz", email: nil, email_2: nil, searchable: false, with_user: false, affiliations: 1 },
  { first_name: "Rosario", last_name: "De La Cruz-Santos", email: "rosario.dlcs@outlook.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },

  # --- Mixed singles (6 people, similar first names across families) ---
  { first_name: "Maria", last_name: "De La Cruz", email: "maria.dlc@hotmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Maria", last_name: "Smith", email: nil, email_2: "maria.smith@backup.org", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Maria", last_name: "Williams", email: "maria.w@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Sarah", last_name: "Garcia", email: "sarah.garcia@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },
  { first_name: "Sarah", last_name: "Brown", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Sarah", last_name: "Davis", email: "sarah.davis@outlook.com", email_2: "sd@alt.com", searchable: true, with_user: true, affiliations: 2 }
]

test_people.each do |data|
  next if Person.where(
    "LOWER(first_name) = ? AND LOWER(last_name) = ? AND LOWER(COALESCE(email, '')) = ?",
    data[:first_name].downcase,
    data[:last_name].downcase,
    (data[:email] || "").downcase
  ).exists?

  person_attrs = {
    first_name: data[:first_name],
    last_name: data[:last_name],
    email: data[:email],
    email_2: data[:email_2],
    profile_is_searchable: data[:searchable],
    created_by: admin_user,
    updated_by: admin_user
  }

  if data[:with_user]
    user_email = data[:email] || "#{data[:first_name].downcase.gsub(' ', '')}.#{data[:last_name].downcase.gsub(' ', '')}@example.com"
    user = User.where(email: user_email).first_or_create!(
      email: user_email,
      first_name: data[:first_name],
      last_name: data[:last_name],
      password: "password",
      password_confirmation: "password",
      confirmed_at: Time.current
    )

    unless user.person.present?
      person = Person.create!(person_attrs)
      user.update!(person: person)
    end
  else
    Person.create!(person_attrs)
  end
end

# Create affiliations for test people
Person.where(
  "LOWER(last_name) IN (?)",
  %w[johnson johnston johnstone garcia garcia-lopez smith smithson williams williamson brown browning davis davidson cruz cruz-santos]
).find_each do |person|
  match = test_people.find { |d| d[:first_name] == person.first_name && d[:last_name] == person.last_name }
  next unless match
  next if match[:affiliations].zero?
  next if person.affiliations.count >= match[:affiliations]

  needed = match[:affiliations] - person.affiliations.count
  needed.times do
    org = orgs.sample
    next unless org
    next if person.affiliations.exists?(organization: org)

    title = [
      "Facilitator", "Lead Facilitator", "Co-Facilitator",
      "Assistant Facilitator", "Volunteer", "Board Member"
    ].sample
    Affiliation.create!(
      person: person,
      organization: org,
      title: title,
      position: [ :default, :liaison, :leader, :assistant ].sample,
      start_date: rand(1..5).years.ago.to_date,
      inactive: [ false, false, false, true ].sample
    )
  end
end

puts "Assigning addresses and sectors to people…"
# Curated state/county pairs so the event overview's States and Counties cards
# show a recognizable spread rather than scattered random values.
person_locations = [
  { state: "CA", county: "Los Angeles", city: "Los Angeles", locality: "LA City" },
  { state: "CA", county: "Orange", city: "Santa Ana", locality: "Orange County" },
  { state: "CA", county: "San Francisco", city: "San Francisco", locality: "Northern CA" },
  { state: "NY", county: "Kings", city: "Brooklyn", locality: "Outside CA" },
  { state: "TX", county: "Travis", city: "Austin", locality: "Outside CA" },
  { state: "WA", county: "King", city: "Seattle", locality: "Outside CA" },
  { state: "IL", county: "Cook", city: "Chicago", locality: "Outside CA" }
]
person_sector_pool = Sector.all.to_a

Person.find_each.with_index do |person, i|
  if person.addresses.empty?
    loc = person_locations[i % person_locations.size]
    person.addresses.create!(
      address_type: "personal",
      street_address: Faker::Address.street_address,
      city: loc[:city],
      state: loc[:state],
      county: loc[:county],
      locality: loc[:locality],
      zip_code: Faker::Address.zip_code,
      primary: true
    )
  end

  if person_sector_pool.any? && person.sectors.empty?
    person_sector_pool.sample(rand(1..3)).each do |sector|
      SectorableItem.find_or_create_by!(
        sector_id: sector.id,
        sectorable_type: "Person",
        sectorable_id: person.id
      )
    end
  end
end

puts "Tagging seed users with primary/additional age groups…"
# A person serves one core age group and sometimes a few others, so the profile
# and recipients pages show a single starred primary chip plus any additional
# ones. Give the three demo accounts that shape so the chip display has real data
# to render. tag_age_groups marks exactly the named primary and treats the rest
# as additional, and is idempotent on reseed.
seed_user_age_groups = {
  "umberto.user@example.com" => { primary: "13-17", additional: [ "18+" ] },
  "amy.user@example.com" => { primary: "6-12", additional: [ "3-5", "13-17" ] },
  "aisha.user@example.com" => { primary: "18+", additional: [] }
}
seed_user_age_groups.each do |email, groups|
  person = User.find_by(email: email)&.person
  next unless person

  primary = Category.age_ranges.published.find_by(name: groups[:primary])
  next unless primary

  additional = Category.age_ranges.published.where(name: groups[:additional]).to_a
  person.tag_age_groups(primary_ids: [ primary.id ], additional_ids: additional.map(&:id))
end
