# frozen_string_literal: true

require "rails_helper"

RSpec.describe(WindowsType) do
  describe "associations" do
    it { is_expected.to(have_many(:workshops)) }
    it { is_expected.to(have_many(:age_ranges)) }
    it { is_expected.to(have_many(:reports)) }
    it { is_expected.to(have_many(:form_builders)) }
  end

  it "is valid with valid attributes" do
    expect(build(:windows_type)).to(be_valid)
  end

  # Add tests for methods like #label, #log_label, etc.
end
