# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Banner) do
  # let(:banner) { build(:banner) } # Keep if needed for other tests

  describe "validations" do
    subject { build(:banner) }

    it { is_expected.to(validate_presence_of(:content)) }
  end

  # Basic validity test included via shoulda
  # it 'is valid with valid attributes' do
  #   expect(build(:banner)).to be_valid
  # end
end
