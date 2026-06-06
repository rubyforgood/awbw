# Organization seeds (dev-only) - run on their own via `rake db:seed:organizations`,
# or as part of `rake db:seed:dev`.

puts "Creating Organizations…"
active_status = OrganizationStatus.find_by!(name: "Active")
inactive_status = OrganizationStatus.find_by!(name: "Inactive")
pending_status = OrganizationStatus.find_by!(name: "Pending")
suspended_status = OrganizationStatus.find_by!(name: "Suspended")

adult_wt = WindowsType.find_by!(short_name: "Adult")
children_wt = WindowsType.find_by!(short_name: "Children")
combined_wt = WindowsType.find_by!(short_name: "Combined")

[
  { name: "1736 Family Crisis Center", organization_status: inactive_status, windows_type: adult_wt },
  { name: "Angel Step Inn", organization_status: active_status, windows_type: adult_wt },
  { name: "YWCA of San Diego - Becky's House", organization_status: active_status, windows_type: children_wt },
  { name: "Good Shepherd Shelter", organization_status: active_status, windows_type: adult_wt },
  { name: "One Safe Place", organization_status: active_status, windows_type: adult_wt },
  { name: "Haven Hills", organization_status: active_status, windows_type: children_wt },
  { name: "Survivor's Art Circle", organization_status: active_status, windows_type: children_wt },
  { name: "YWCA Spokane", organization_status: inactive_status, windows_type: adult_wt },
  { name: "Center for Battered Women", organization_status: pending_status, windows_type: children_wt },
  { name: "Asian Women Shelter", organization_status: active_status, windows_type: adult_wt },
  { name: "Deaf Hope", organization_status: active_status, windows_type: children_wt },
  { name: "YWCA of Monterey County", organization_status: active_status, windows_type: adult_wt },
  { name: "Joyful Heart Foundation", organization_status: suspended_status, windows_type: adult_wt },
  { name: "Domestic Violence Center of Santa Clarita Valley", organization_status: pending_status, windows_type: adult_wt },
  { name: "Abused Women's Aid in Crisis", organization_status: active_status, windows_type: adult_wt },
  { name: "Friends of the Family", organization_status: active_status, windows_type: adult_wt },
  { name: "Haven House", organization_status: active_status, windows_type: adult_wt },
  { name: "Laurel House", organization_status: active_status, windows_type: adult_wt },
  { name: "Alternatives for Battered Women", organization_status: active_status, windows_type: adult_wt },
  { name: "Humboldt Women for Shelter", organization_status: active_status, windows_type: children_wt }
].each do |org_data|
  Organization.where(name: org_data[:name]).first_or_create!(org_data)
end
