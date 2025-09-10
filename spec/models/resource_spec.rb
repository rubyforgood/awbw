# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Resource) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:user)) }
    it { is_expected.to(belong_to(:workshop).optional) }
    it { is_expected.to(belong_to(:windows_type)) }
    it { is_expected.to(have_many(:images).dependent(:destroy)) } # As owner
    it { is_expected.to(have_many(:categorizable_items).dependent(:destroy)) } # As categorizable
    it { is_expected.to(have_many(:categories).through(:categorizable_items)) }
    it { is_expected.to(have_many(:sectorable_items).dependent(:destroy)) } # As sectorable
    it { is_expected.to(have_many(:sectors).through(:sectorable_items)) }
    # related_workshops through sectors through sectorable_items - complex, test manually if needed
    # it { should have_many(:related_workshops).through(:sectors) }
    it { is_expected.to(have_many(:attachments).dependent(:destroy)) } # As owner
    it { is_expected.to(have_many(:reports)) } # As owner
    it { is_expected.to(have_many(:workshop_resources).dependent(:destroy)) }
    it { is_expected.to(have_one(:form)) } # As owner

    # Nested Attributes
    it { is_expected.to(accept_nested_attributes_for(:categorizable_items).allow_destroy(true)) }
    it { is_expected.to(accept_nested_attributes_for(:sectorable_items).allow_destroy(true)) }
    it { is_expected.to(accept_nested_attributes_for(:images).allow_destroy(true)) }
    it { is_expected.to(accept_nested_attributes_for(:attachments).allow_destroy(true)) }
    it { is_expected.to(accept_nested_attributes_for(:form).allow_destroy(true)) }
  end

  describe "validations" do
    # Requires associations for create
    subject do
      create(:permission, :adult)
      create(:permission, :children)
      create(:permission, :combined)
      build(:resource, user: create(:user), windows_type: create(:windows_type))
    end

    it { is_expected.to(validate_presence_of(:title)) }
  end

  it "is valid with valid attributes" do # rubocop:todo RSpec/NoExpectationExample
    # NOTE: Factory needs associations uncommented for create
    # expect(build(:resource)).to be_valid
  end

  # Add tests for methods like #name, #main_image_url, scopes, SearchCop etc.
end
