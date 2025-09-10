# frozen_string_literal: true

require "rails_helper"

RSpec.describe(ProjectObligation) do
  it "is valid with valid attributes" do
    expect(build(:project_obligation)).to(be_valid)
  end
end
