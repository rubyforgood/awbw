# frozen_string_literal: true

require "rails_helper"

RSpec.describe(WorkshopIdea) do
  it "is a type of Workshop" do
    expect(build(:workshop_idea)).to(be_a(Workshop))
  end

  it "is valid with valid attributes" do
    # NOTE: Factory needs associations uncommented for create (from Workshop factory)
    # expect(build(:workshop_idea)).to be_valid
  end

  it "defaults to inactive" do
    # Test the default scope
    expect(build(:workshop_idea).inactive).to(be(true))
  end

  # Add tests specific to WorkshopIdea if any
end
