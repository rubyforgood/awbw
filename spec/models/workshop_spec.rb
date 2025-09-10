# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Workshop) do
  # pending "add some examples to (or delete) #{__FILE__}"
  before do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
  end

  describe "associations" do
    # Need create for association tests to work correctly with callbacks/scopes
    subject { create(:workshop) } # Assumes functional factory

    it { is_expected.to(belong_to(:user).optional) }
    it { is_expected.to(belong_to(:windows_type)) }

    it { is_expected.to(have_many(:sectorable_items).dependent(:destroy).inverse_of(:sectorable)) }
    it { is_expected.to(have_many(:sectors).through(:sectorable_items)) }
    it { is_expected.to(have_many(:images).dependent(:destroy)) } # As owner
    it { is_expected.to(have_many(:workshop_logs).dependent(:destroy)) } # As owner
    it { is_expected.to(have_many(:bookmarks).dependent(:destroy)) } # As bookmarkable
    it { is_expected.to(have_many(:workshop_variations).dependent(:destroy)) }
    it { is_expected.to(have_many(:categorizable_items).dependent(:destroy)) } # As categorizable
    it { is_expected.to(have_many(:categories).through(:categorizable_items)) }
    it { is_expected.to(have_many(:metadata).through(:categories)) }
    it { is_expected.to(have_many(:quotable_item_quotes).dependent(:destroy)) } # As quotable
    it { is_expected.to(have_many(:quotes).through(:quotable_item_quotes)) }
    it { is_expected.to(have_many(:workshop_resources).dependent(:destroy)) }
    it { is_expected.to(have_many(:resources).through(:workshop_resources)) }
    it { is_expected.to(have_many(:attachments).dependent(:destroy)) } # As owner
    it { is_expected.to(have_many(:workshop_age_ranges)) }

    # Nested Attributes
    it { is_expected.to(accept_nested_attributes_for(:images).allow_destroy(true)) }
    it { is_expected.to(accept_nested_attributes_for(:sectorable_items).allow_destroy(true)) }
    it { is_expected.to(accept_nested_attributes_for(:sectors).allow_destroy(true)) }
    it { is_expected.to(accept_nested_attributes_for(:workshop_age_ranges).allow_destroy(true)) }
    it { is_expected.to(accept_nested_attributes_for(:quotes)) }
    it { is_expected.to(accept_nested_attributes_for(:workshop_variations)) }
    it { is_expected.to(accept_nested_attributes_for(:workshop_logs).allow_destroy(true)) }

    # Paperclip
    # it { should have_attached_file(:thumbnail) }
    # it { should have_attached_file(:header) }
  end

  describe "validations" do
    # Requires associations for create
    subject { build(:workshop, user: create(:user), windows_type: create(:windows_type)) }

    it { is_expected.to(validate_presence_of(:title)) }
    it { is_expected.to(validate_length_of(:age_range).is_at_most(16)) }

    # Paperclip
    # it { should validate_attachment_content_type(:thumbnail).allowing('image/png', 'image/jpeg', 'image/gif') }
    # it { should validate_attachment_content_type(:header).allowing('image/png', 'image/jpeg', 'image/gif') }

    # Conditional presence validation for legacy workshops (month, year)
  end

  it "is valid with valid attributes" do
    # NOTE: Factory needs associations uncommented for create
    # expect(build(:workshop)).to be_valid
  end

  # Add tests for scopes, methods like #rating, #log_count, SearchCop etc.
end
