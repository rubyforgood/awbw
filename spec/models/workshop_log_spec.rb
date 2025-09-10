# frozen_string_literal: true

require "rails_helper"

RSpec.describe(WorkshopLog) do
  # pending "add some examples to (or delete) #{__FILE__}"

  it "is a type of Report" do
    expect(build(:workshop_log)).to(be_a(Report))
  end

  describe "associations" do
    # Explicitly defined here
    it { is_expected.to(belong_to(:workshop)) }
    it { is_expected.to(belong_to(:user)) } # Inherited via Report but also explicit?
    it { is_expected.to(belong_to(:project)) } # Inherited via Report but also explicit?
    it { is_expected.to(have_many(:media_files)) }

    # Inherited from Report
    # it { should belong_to(:windows_type) }
    # it { should belong_to(:owner).optional } # Should be Workshop in this case
    # it { should have_many(:report_form_field_answers).dependent(:destroy) }
    # ... other Report associations
  end

  it "is valid with valid attributes" do
    # NOTE: Factory needs associations uncommented for create
    # expect(build(:workshop_log)).to be_valid
  end

  # Add tests for specific methods like #num_ongoing, #num_first_time, callbacks
end
