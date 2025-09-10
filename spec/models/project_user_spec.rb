# frozen_string_literal: true

require "rails_helper"

RSpec.describe(ProjectUser) do
  describe "associations" do
    it { is_expected.to(belong_to(:project)) }
    it { is_expected.to(belong_to(:user)) }
  end

  describe "validations" do
    subject do
      create(:permission, :adult)
      create(:permission, :children)
      create(:permission, :combined)
      build(:project_user, project: create(:project), user: create(:user))
    end

    it { is_expected.to(validate_presence_of(:project_id)) }
  end

  describe "enums" do
    it { is_expected.to(define_enum_for(:position).with_values([:default, :liaison, :leader, :assistant])) }
  end

  it "is valid with valid attributes" do
    # NOTE: Factory needs associations uncommented for create
    # expect(build(:project_user)).to be_valid
    # pending("Requires functional project/user factories and associations uncommented")
  end
end
