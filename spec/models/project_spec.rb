# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Project) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:location)) }
    it { is_expected.to(belong_to(:windows_type)) }
    it { is_expected.to(belong_to(:project_status)) }
    it { is_expected.to(have_many(:project_users)) }
    it { is_expected.to(have_many(:users).through(:project_users)) }
    it { is_expected.to(have_many(:reports).through(:users)) }
    it { is_expected.to(have_many(:workshop_logs).through(:users)) }
  end

  it "is valid with valid attributes" do
    # NOTE: Factory needs associations uncommented for create
    # expect(build(:project)).to be_valid
  end

  # Add tests for methods like #led_by?, #log_title
end
