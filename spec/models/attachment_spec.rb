# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Attachment) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:owner)) } # Polymorphic
  end

  # it 'is valid with an owner' do
  #   # Note: Factory needs an owner to be valid for create
  #   expect(build(:attachment, owner: create(:user))).to be_valid
  # end
end
