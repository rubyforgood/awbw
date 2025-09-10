# frozen_string_literal: true

require "rails_helper"

RSpec.describe(AgeRange) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    subject { build(:age_range, windows_type: create(:windows_type)) }

    it { is_expected.to(belong_to(:windows_type)) }
  end

  it "is valid with valid attributes" do
    expect(build(:age_range)).to(be_valid)
  end
end
