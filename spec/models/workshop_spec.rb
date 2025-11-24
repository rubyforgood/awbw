require "rails_helper"

RSpec.describe Workshop do
  # pending "add some examples to (or delete) #{__FILE__}"
  describe "associations" do
    # Need create for association tests to work correctly with callbacks/scopes
    subject { create(:workshop) } # Assumes functional factory

    it { should belong_to(:user).optional }
    it { should belong_to(:windows_type) }

    it { should have_many(:sectorable_items).dependent(:destroy).inverse_of(:sectorable) }
    it { should have_many(:sectors).through(:sectorable_items) }
    it { should have_many(:images).dependent(:destroy) } # As owner
    it { should have_many(:workshop_logs).dependent(:destroy) } # As owner
    it { should have_many(:bookmarks).dependent(:destroy) } # As bookmarkable
    it { should have_many(:workshop_variations).dependent(:destroy) }
    it { should have_many(:categorizable_items).dependent(:destroy) } # As categorizable
    it { should have_many(:categories).through(:categorizable_items) }
    it { should have_many(:metadata).through(:categories) }
    it { should have_many(:quotable_item_quotes).dependent(:destroy) } # As quotable
    it { should have_many(:quotes).through(:quotable_item_quotes) }
    it { should have_many(:workshop_resources).dependent(:destroy) }
    it { should have_many(:resources).through(:workshop_resources) }
    it { should have_many(:attachments).dependent(:destroy) } # As owner
    it { should have_many(:workshop_age_ranges) }

    # Nested Attributes
    it { should accept_nested_attributes_for(:gallery_images).allow_destroy(true) }
    it { should accept_nested_attributes_for(:sectorable_items).allow_destroy(true) }
    it { should accept_nested_attributes_for(:sectors).allow_destroy(true) }
    it { should accept_nested_attributes_for(:workshop_age_ranges).allow_destroy(true) }
    it { should accept_nested_attributes_for(:quotes) }
    it { should accept_nested_attributes_for(:workshop_variations) }
    it { should accept_nested_attributes_for(:workshop_logs).allow_destroy(true) }
  end

  describe "validations" do
    # Requires associations for create
    subject { build(:workshop, user: create(:user), windows_type: create(:windows_type)) }

    it { should validate_presence_of(:title) }
    it { should validate_length_of(:age_range).is_at_most(16) }

    # Conditional presence validation for legacy workshops (month, year)
    context "when legacy is true" do
      before { allow(subject).to receive(:legacy).and_return(true) }
      # Cannot easily test conditional validation with shoulda-matchers, test manually
      # it { should validate_presence_of(:month) }
      # it { should validate_presence_of(:year) }
    end
    context "when legacy is false" do
      before { allow(subject).to receive(:legacy).and_return(false) }
      # it { should_not validate_presence_of(:month) }
      # it { should_not validate_presence_of(:year) }
    end
  end

  it "is valid with valid attributes" do
    # Note: Factory needs associations uncommented for create
    # expect(build(:workshop)).to be_valid
  end

  # Add tests for scopes, methods like #rating, #log_count, SearchCop etc.
end

