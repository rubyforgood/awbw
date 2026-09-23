FactoryBot.define do
  factory :invoice do
    sequence(:number) { |n| "#{ENV.fetch("INVOICE_PREFIX", "INV")}-#{format('%03d', n)}" }
    date { Date.current }
    client { create(:person) }
    bill_to_address { "123 Main St\nLos Angeles, CA 90001" }
    total_cents { 150_000 }

    trait :with_line_items do
      after(:create) do |invoice|
        create(:invoice_line_item, invoice: invoice, description: "Service description", quantity: 1, unit_price_cents: 150_000)
      end
    end
  end
end
