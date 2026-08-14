json.name grant.name

json.funder do
  json.name grant.funder_name
  json.type grant.funder_type
end

json.funds do
  json.amount_cents grant.amount_cents
  json.amount dollars_from_cents(grant.amount_cents)
end

json.description grant.description
json.eligibility_criteria grant.eligibility_criteria_list
json.tasks grant.task_list

# Tags applied to the grant: categories (grouped by category type) and sectors.
json.tags do
  # Always emit `categories` as an object (`{}` when untagged) so consumers can
  # iterate it unconditionally.
  json.categories grant.categories
    .group_by { |c| c.category_type&.display_label || "Other" }
    .transform_values { |cats| cats.map(&:name).sort }
  json.sectors grant.sectors.map(&:name).sort
end

json.scholarships_count grant.scholarships.size
