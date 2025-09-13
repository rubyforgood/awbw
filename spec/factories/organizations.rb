FactoryBot.define do
  factory :organization do
    name { "Los Angeles Community Development Corporation" }
    start_date { "2020-01-15" }
    close_date { nil }
    website_url { "https://www.lacdc.org" }
    agency_type { "Non-Profit" }
    agency_type_other { nil }
    phone { "(213) 555-0123" }
    mission { "To promote community development and provide essential services to underserved populations in Los Angeles County." }
    project_id { "1717" }
  end
end
