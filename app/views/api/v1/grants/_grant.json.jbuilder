json.name grant.name

json.funder do
  json.name grant.funder_name
  json.type grant.funder_type
end

json.funds do
  json.amount_cents grant.amount_cents
  json.amount dollars_from_cents(grant.amount_cents)
  json.allocated_cents grant.scholarships_total_cents
  json.allocated dollars_from_cents(grant.scholarships_total_cents)
  json.remaining_cents grant.remaining_cents
  json.remaining dollars_from_cents(grant.remaining_cents)
  json.fully_issued grant.remaining_cents <= 0
end

json.funds_received_on grant.funds_received_on&.iso8601
json.funds_allocation_deadline grant.funds_allocation_deadline&.iso8601

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

json.created_at grant.created_at.iso8601
json.updated_at grant.updated_at.iso8601
