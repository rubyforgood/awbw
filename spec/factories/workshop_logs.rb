FactoryBot.define do
  factory :workshop_log, parent: :report, class: 'WorkshopLog' do
    type { "WorkshopLog" }

    association :owner, factory: :workshop

    workshop { owner }

  end
end
