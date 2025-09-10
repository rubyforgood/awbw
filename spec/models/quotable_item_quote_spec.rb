# frozen_string_literal: true

require "rails_helper"

RSpec.describe(QuotableItemQuote) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:quote)) }
    it { is_expected.to(belong_to(:quotable)) } # Polymorphic
    it { is_expected.to(accept_nested_attributes_for(:quote)) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:quotable_item_quote)).to be_valid
  #   pending("Requires functional quote/quotable factories and associations uncommented")
  # end
end
