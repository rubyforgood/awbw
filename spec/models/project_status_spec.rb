# frozen_string_literal: true

require "rails_helper"

RSpec.describe(ProjectStatus) do
  it "is valid with valid attributes" do
    expect(build(:project_status)).to(be_valid)
  end
end
