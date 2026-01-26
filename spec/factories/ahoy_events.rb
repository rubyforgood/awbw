FactoryBot.define do
  factory :ahoy_event, class: "Ahoy::Event" do
    association :visit, factory: :ahoy_visit
    name { "view.workshop" }
    properties { { resource_type: "Workshop", resource_id: 1, resource_title: "Test Resource" } }
    time { Time.current }
  end
end
