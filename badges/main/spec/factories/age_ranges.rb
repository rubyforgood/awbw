FactoryBot.define do
  factory :age_range do
    name { "6-12" }
    # Association: belongs_to :windows_type
    association :windows_type
  end
end
