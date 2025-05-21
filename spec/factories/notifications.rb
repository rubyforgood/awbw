FactoryBot.define do
  factory :notification do
    association :noticeable, factory: :report

    notification_type { :created }

    after(:build) do |notification|
       allow(notification).to receive(:send_notice).and_return(true)
    end
  end
end 