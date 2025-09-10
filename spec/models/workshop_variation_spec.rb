# frozen_string_literal: true

require "rails_helper"

RSpec.describe(WorkshopVariation) do
  describe "associations" do
    it { is_expected.to(belong_to(:workshop)) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs association uncommented for create
  #   # expect(build(:workshop_variation)).to be_valid
  #   pending("Requires functional workshop factory and association uncommented")
  # end
end
