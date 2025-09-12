FactoryBot.define do
  factory :metadatum do
    sequence(:name) { |n| "Metadatum Name #{n}" }
    published { true }
  end
end 