# frozen_string_literal: true

FactoryBot.define do
  factory :story, parent: :report, class: "Story" do
    type { "Story" }

    association :owner, factory: :form_builder
  end
end
