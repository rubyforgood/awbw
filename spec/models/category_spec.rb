# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Category) do
  let(:category) { build(:category) }

  # rubocop:todo RSpec/RepeatedExampleGroupDescription
  describe "associations" do # rubocop:todo RSpec/RepeatedExampleGroupBody # rubocop:todo RSpec/RepeatedExampleGroupDescription
    it { is_expected.to(belong_to(:metadatum)) }
    it { is_expected.to(have_many(:categorizable_items).dependent(:destroy)) }
    it { is_expected.to(have_many(:workshops).through(:categorizable_items)) }
  end
  # rubocop:enable RSpec/RepeatedExampleGroupDescription

  describe "validations" do
    subject { build(:category, name: existing_category.name, metadatum: metadatum) }

    let!(:metadatum) { create(:metadatum) }
    let!(:existing_category) { create(:category, metadatum: metadatum) }

    it { is_expected.to(validate_presence_of(:name)) }
  end

  # rubocop:todo RSpec/RepeatedExampleGroupDescription
  describe "associations" do # rubocop:todo RSpec/RepeatedExampleGroupBody # rubocop:todo RSpec/RepeatedExampleGroupDescription
    it { is_expected.to(belong_to(:metadatum)) }
    it { is_expected.to(have_many(:categorizable_items).dependent(:destroy)) }
    it { is_expected.to(have_many(:workshops).through(:categorizable_items)) }
  end
  # rubocop:enable RSpec/RepeatedExampleGroupDescription
end
