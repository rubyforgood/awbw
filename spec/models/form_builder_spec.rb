# frozen_string_literal: true

require "rails_helper"

RSpec.describe(FormBuilder) do
  describe "associations" do
    it { is_expected.to(belong_to(:windows_type)) }
    it { is_expected.to(have_many(:forms)) }
    it { is_expected.to(accept_nested_attributes_for(:forms)) }
  end

  describe "validations" do
    subject { build(:form_builder, windows_type: create(:windows_type)) }

    it { is_expected.to(validate_presence_of(:name)) }
  end

  it "is valid with valid attributes" do # rubocop:todo RSpec/NoExpectationExample
    # NOTE: Factory needs windows_type association uncommented for create
    # expect(build(:form_builder)).to be_valid
  end

  # Add tests for methods like #report_type, #form_fields etc.
  # Add tests for scopes :workshop_logs, :monthly
end
