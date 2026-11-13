# Organizations that exercise every OrganizationServices::DuplicateFinder name and
# FileMaker-code signal, so the Dedupe organizations page has one group per rule to
# merge, plus near-misses that must stay out. Re-running is a no-op once seeded.

sentinel_name = "Harbor Light Shelter"

if Organization.exists?(name: sentinel_name)
  puts "Skipping organization duplicates seed (already seeded)"
else
  puts "Seeding organizations for the organization deduper…"

  add = ->(name, filemaker_code = nil) { Organization.create!(name:, filemaker_code:) }

  # Same name aside from punctuation
  add.(sentinel_name)
  add.("Harbor-Light Shelter")

  # Same name aside from Inc/LLC/etc.
  add.("Riverbend Family Services Inc")
  add.("Riverbend Family Services, LLC")

  # Same name aside from a trailing audience word
  add.("Maple Grove Center Children's")
  add.("Maple Grove Center Adult")
  add.("Maple Grove Center Combined")
  add.("Maple Grove Center Women's")

  # Same name aside from a FileMaker code in the name
  add.("Cedar Hollow Outreach", "ORG80001")
  add.("Cedar Hollow Outreach (ORG80002)", "ORG80002")
  add.("Cedar Hollow Outreach (P8001)", "P8001")

  # A FileMaker code stacked on an audience word or legal suffix
  add.("Lakeview Haven Inc")
  add.("Lakeview Haven Women's (ORG80003)", "ORG80003")
  add.("Lakeview Haven Combined ORG80004", "ORG80004")

  # Different names sharing a FileMaker code; merging keeps every code once
  add.("Sunrise House", "ORG80005, P8002")
  add.("Sunrise Home", "ORG80005, P8003")

  # Near-misses: a trailing word that isn't an audience word, a number that isn't
  # a FileMaker code, and a bare "Women" that ends a real name
  add.("Maple Grove Center Programs")
  add.("Cedar Hollow Outreach 2024")
  add.("Harbor Light Women")

  groups = OrganizationServices::DuplicateFinder.new.groups
  puts "  #{groups.size} duplicate organization groups ready on the Dedupe organizations page"
end
