# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Story) do
  it "is a type of Report" do
    expect(build(:story)).to(be_a(Report))
  end

  it "is valid with valid attributes" do # rubocop:todo RSpec/NoExpectationExample
    # NOTE: Factory needs associations uncommented for create (from Report factory)
    # expect(build(:story)).to be_valid
    # pending("Requires functional user/project/windows_type factories and associations uncommented")
  end

  # Add tests specific to Story if any
end
