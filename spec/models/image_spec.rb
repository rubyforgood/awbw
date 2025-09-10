# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Image) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:owner)) } # Polymorphic
    it { is_expected.to(belong_to(:report).optional) } # Assuming report can be optional
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs owner and/or report associations uncommented for create
  #   # expect(build(:image)).to be_valid
  #   pending("Requires functional owner/report factories and associations uncommented")
  # end
end
