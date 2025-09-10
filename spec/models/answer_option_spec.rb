# frozen_string_literal: true

require "rails_helper"

RSpec.describe(AnswerOption) do
  # Example basic validity test (optional if using shoulda matchers)
  it "is valid with valid attributes" do
    expect(build(:answer_option)).to(be_valid)
  end
end
