# Addresses that exercise every AddressNormalizer / AddressDeduper rule, so the
# Dedupe addresses page (/addresses/dedupe_index) has one set per rule to merge,
# plus near-misses that must stay separate. Each case sits in its own city so the
# sets don't run into each other. Re-running is a no-op once the sampler org exists.

sampler_name = "Address Dedupe Sampler (seed)"

if Organization.exists?(name: sampler_name)
  puts "Skipping address duplicates seed (already seeded)"
else
  puts "Seeding addresses for the address deduper…"

  base = {
    street_address: "", city: "", state: "CA", zip_code: "", country: "USA",
    county: nil, district: nil, address_type: "work", locality: "Unknown"
  }
  add = ->(owner, **attrs) { owner.addresses.create!(base.merge(attrs)) }

  sampler = Organization.create!(name: sampler_name)
  neighbor = Organization.create!(name: "Address Dedupe Neighbor (seed)")
  person = Person.create!(first_name: "Dedupe", last_name: "Addresses Sample", email: "dedupe.addresses@example.com")

  # ── Merge: spelling translations ──
  # Street suffix + directional
  add.(sampler, street_address: "100 North Main Street", city: "Suffixville", zip_code: "90101", primary: true)
  add.(sampler, street_address: "100 N. Main St.", city: "Suffixville", zip_code: "90101")
  # Unit designators (Suite / Apt / #)
  add.(sampler, street_address: "200 Oak Ave Suite 4", city: "Unitburg", zip_code: "90102")
  add.(sampler, street_address: "200 Oak Avenue #4", city: "Unitburg", zip_code: "90102")
  add.(sampler, street_address: "200 Oak Ave Apt. 4", city: "Unitburg", zip_code: "90102")
  # Ordinal street names
  add.(sampler, street_address: "300 First Avenue", city: "Ordinal Falls", zip_code: "90103")
  add.(sampler, street_address: "300 1st Ave", city: "Ordinal Falls", zip_code: "90103")
  # P.O. Box
  add.(sampler, street_address: "Post Office Box 12", city: "Boxford", zip_code: "90104")
  add.(sampler, street_address: "P.O. Box 12", city: "Boxford", zip_code: "90104")
  # Saint / Fort / Mount in the city
  add.(sampler, street_address: "400 Market St", city: "Saint Helena", zip_code: "94574")
  add.(sampler, street_address: "400 Market St", city: "St. Helena", zip_code: "94574")
  add.(sampler, street_address: "410 Pine St", city: "Fort Bragg", zip_code: "95437")
  add.(sampler, street_address: "410 Pine St", city: "Ft. Bragg", zip_code: "95437")
  add.(sampler, street_address: "420 Lake St", city: "Mount Shasta", zip_code: "96067")
  add.(sampler, street_address: "420 Lake St", city: "Mt Shasta", zip_code: "96067")
  # State name vs abbreviation
  add.(sampler, street_address: "500 Broadway", city: "Statesboro", state: "California", zip_code: "90105")
  add.(sampler, street_address: "500 Broadway", city: "Statesboro", state: "CA", zip_code: "90105")
  # ZIP+4 vs five-digit ZIP
  add.(sampler, street_address: "600 Elm St", city: "Zipton", zip_code: "90106-1234")
  add.(sampler, street_address: "600 Elm St", city: "Zipton", zip_code: "90106")
  # Country spellings, and a blank country in a US state
  add.(sampler, street_address: "700 Cedar St", city: "Countryside", zip_code: "90107", country: "USA")
  add.(sampler, street_address: "700 Cedar St", city: "Countryside", zip_code: "90107", country: "United States of America")
  add.(sampler, street_address: "700 Cedar St", city: "Countryside", zip_code: "90107", country: "U. S. A.")
  add.(sampler, street_address: "700 Cedar St", city: "Countryside", zip_code: "90107", country: nil)
  # Trailing "County"
  add.(sampler, street_address: "800 Birch St", city: "Countyline", zip_code: "90108", county: "Los Angeles County")
  add.(sampler, street_address: "800 Birch St", city: "Countyline", zip_code: "90108", county: "Los Angeles")
  # Unknown locality and type match a known one (the kept copy picks up "LA City" and "work")
  add.(sampler, street_address: "900 Maple St", city: "Localeton", zip_code: "90109", locality: "Unknown", address_type: nil)
  add.(sampler, street_address: "900 Maple St", city: "Localeton", zip_code: "90109", locality: "LA City")
  # Case and extra spaces only
  add.(sampler, street_address: "  950 WILLOW st ", city: "spacetown ", zip_code: "90110")
  add.(sampler, street_address: "950 Willow St", city: "Spacetown", zip_code: "90110")

  # ── Merge: partial copies ──
  # Missing ZIP — the kept (older) copy picks up the ZIP
  add.(sampler, street_address: "1000 Spruce St", city: "Partialton", zip_code: "")
  add.(sampler, street_address: "1000 Spruce St", city: "Partialton", zip_code: "90111")
  # A chain of ever-less-complete copies lands on the fullest
  add.(sampler, street_address: "1100 Aspen St", city: "Chainville", zip_code: "90112")
  add.(sampler, street_address: "1100 Aspen St", city: "Chainville", zip_code: "")
  add.(sampler, street_address: "", city: "Chainville", zip_code: "")

  # ── Merge: which copy is kept ──
  # Inactive older copy loses to the active newer one
  add.(sampler, street_address: "1200 Poplar St", city: "Keeperton", zip_code: "90113", inactive: true)
  add.(sampler, street_address: "1200 Poplar Street", city: "Keeperton", zip_code: "90113")

  # ── Stay separate ──
  # Typo
  add.(sampler, street_address: "1300 Main St", city: "Typoville", zip_code: "90114")
  add.(sampler, street_address: "1300 Mian St", city: "Typoville", zip_code: "90114")
  # Two different known localities
  add.(sampler, street_address: "1400 Vine St", city: "Splitburg", zip_code: "90115", locality: "LA City")
  add.(sampler, street_address: "1400 Vine St", city: "Splitburg", zip_code: "90115", locality: "Outside CA")
  # Different address types
  add.(sampler, street_address: "1500 Ash St", city: "Typeton", zip_code: "90116", address_type: "work")
  add.(sampler, street_address: "1500 Ash St", city: "Typeton", zip_code: "90116", address_type: "mailing")
  # A street-less copy that fits two different streets
  add.(sampler, street_address: "1 Elm St", city: "Twin Oaks", zip_code: "90117")
  add.(sampler, street_address: "2 Pine St", city: "Twin Oaks", zip_code: "90117")
  add.(sampler, street_address: "", city: "Twin Oaks", zip_code: "90117")
  # Same address on another organization — never merged across owners, but the
  # organization deduper flags the pair as "Shared address"
  add.(neighbor, street_address: "100 North Main Street", city: "Suffixville", zip_code: "90101")

  # ── A person, with a phone pointing at the copy that merges away ──
  add.(person, street_address: "9 North Elm Rd", city: "Saint Louis", state: "MO", zip_code: "63101",
               address_type: "mailing", primary: true)
  moved = add.(person, street_address: "9 N. Elm Road", city: "St. Louis", state: "Missouri", zip_code: "63101-0001",
                       address_type: "mailing", country: nil)
  person.contact_methods.create!(kind: "phone", value: "555-0100", address: moved)

  groups = AddressServices::DuplicateFinder.new.groups
  puts "  #{groups.sum(&:merged_count)} duplicate addresses across #{groups.size} records ready on /addresses/dedupe_index"
end
