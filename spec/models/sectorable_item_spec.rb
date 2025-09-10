# frozen_string_literal: true

require "rails_helper"

RSpec.describe(SectorableItem) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:sector)) }
    it { is_expected.to(belong_to(:sectorable)) } # Polymorphic
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:sectorable_item)).to be_valid
  #   pending("Requires functional sector/sectorable factories and associations uncommented")
  # end
end
