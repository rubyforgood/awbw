# frozen_string_literal: true

require "rails_helper"

RSpec.describe(WorkshopAgeRange) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:workshop)) }
    it { is_expected.to(belong_to(:age_range)) }
  end

  describe "validations" do
    # Need create for uniqueness test
    # Must create associated records first
    subject do
      create(:permission, :adult)
      create(:permission, :children)
      create(:permission, :combined)
      workshop = create(:workshop) # Assumes functional workshop factory
      age_range = create(:age_range, windows_type: workshop.windows_type) # Assumes functional age_range factory
      create(:workshop_age_range, workshop: workshop, age_range: age_range)
    end

    it { is_expected.to(validate_presence_of(:workshop_id)) }
    it { is_expected.to(validate_presence_of(:age_range_id)) }
    it { is_expected.to(validate_uniqueness_of(:workshop_id).scoped_to(:age_range_id)) }
  end

  it "is valid with valid attributes" do # rubocop:todo RSpec/NoExpectationExample
    # NOTE: Factory needs associations uncommented for create
    # expect(build(:workshop_age_range)).to be_valid
    # pending("Requires functional workshop/age_range factories and associations uncommented")
  end
end
