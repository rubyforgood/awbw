# frozen_string_literal: true

require "rails_helper"

RSpec.describe(WorkshopResource) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:workshop)) }
    it { is_expected.to(belong_to(:resource)) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:workshop_resource)).to be_valid
  #   pending("Requires functional workshop/resource factories and associations uncommented")
  # end
end
