FactoryBot.define do
  factory :invoice_line_item do
    association :invoice
    date { Date.current }
    description { "Service description" }
    quantity { 1 }
    unit_price_cents { 150_000 }
  end
end
