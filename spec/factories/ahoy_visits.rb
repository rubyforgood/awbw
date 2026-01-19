FactoryBot.define do
  factory :ahoy_visit, class: "Ahoy::Visit" do
    visit_token { SecureRandom.uuid }
    visitor_token { SecureRandom.uuid }
    started_at { Time.current }
  end
end
