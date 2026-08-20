FactoryBot.define do
  factory :feature do
    sequence(:name) { |n| "Feature #{n}" }
    area { "events" }
    display_status { "user_facing" }
    summary { "A short, plain-language summary of the feature." }
    released_on { Date.new(2026, 8, 1) }
    published { true }

    trait :unpublished do
      published { false }
    end

    trait :admin_facing do
      display_status { "admin_facing" }
    end

    trait :public_facing do
      display_status { "public_facing" }
    end

    trait :with_pro_tips do
      pro_tips { "First tip\nSecond tip" }
    end

    trait :with_description do
      rhino_description { "<p>Full write-up with a screenshot.</p>" }
    end

    trait :with_external_url do
      external_url { "https://docs.example.com/feature" }
    end
  end
end
