FactoryBot.define do
  factory :resource do
    association :user
    title { Faker::Lorem.sentence }
    kind { [Resource::PUBLISHED_KINDS.sample] }

    # Use after(:create) to assign sectors
    after(:create) do |resource|
      sector = create(:sector, name: "General") # adjust factory as needed
      resource.sectors << sector
    end
  end
end
