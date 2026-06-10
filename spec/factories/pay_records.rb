FactoryBot.define do
  factory :pay_customer, class: "Pay::Customer" do
    association :owner, factory: :user
    processor { :stripe }
    processor_id { "cus_#{SecureRandom.hex(8)}" }
  end

  factory :pay_charge, class: "Pay::Charge" do
    association :customer, factory: :pay_customer
    processor_id { "ch_#{SecureRandom.hex(8)}" }
    amount { 30_00 }
    amount_refunded { 0 }
    currency { "usd" }
    metadata { {} }
    object do
      {
        "id" => processor_id,
        "object" => "charge",
        "amount" => amount,
        "currency" => currency,
        "paid" => true,
        "metadata" => metadata,
        "refunds" => { "object" => "list", "data" => [], "has_more" => false }
      }
    end
  end
end
