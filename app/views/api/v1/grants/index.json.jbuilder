json.grants @grants, partial: "api/v1/grants/grant", as: :grant

json.meta do
  json.current_page @grants.current_page
  json.per_page @grants.per_page
  json.total_entries @grants.total_entries
  json.total_pages @grants.total_pages
end
