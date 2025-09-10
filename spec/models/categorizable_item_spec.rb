# frozen_string_literal: true

require "rails_helper"

RSpec.describe(CategorizableItem) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:category)) }
    it { is_expected.to(belong_to(:categorizable)) } # Polymorphic
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs category and categorizable associations uncommented for create
  #   # Example with workshop:
  #   # workshop = create(:workshop)
  #   # category = create(:category) # Needs metadatum
  #   # expect(build(:categorizable_item, categorizable: workshop, category: category)).to be_valid
  #   pending("Requires functional category/workshop factories and associations uncommented")
  # end
end
