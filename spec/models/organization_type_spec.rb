require 'rails_helper'

RSpec.describe OrganizationType, type: :model do
  describe "validations" do
    it "requires a name" do
      expect(build(:organization_type, name: "")).not_to be_valid
    end

    it "enforces case-insensitive name uniqueness" do
      create(:organization_type, name: "Nonprofit")
      expect(build(:organization_type, name: "nonprofit")).not_to be_valid
    end
  end

  describe "scopes" do
    it ".published returns only published types" do
      published = create(:organization_type, :published)
      create(:organization_type, :unpublished)
      expect(described_class.published).to contain_exactly(published)
    end

    it ".name_contains filters by partial, case-insensitive match" do
      match = create(:organization_type, name: "Government agency")
      create(:organization_type, name: "For-profit")
      expect(described_class.name_contains("govern")).to contain_exactly(match)
    end

    it ".ordered sorts digits before letters so defaults read in intended order" do
      OrganizationType::DEFAULT_NAMES.shuffle.each { |name| create(:organization_type, name: name) }
      expect(described_class.ordered.pluck(:name)).to eq(OrganizationType::DEFAULT_NAMES)
    end
  end

  describe ".published_names" do
    it "returns published names ordered" do
      create(:organization_type, :published, name: "For-profit")
      create(:organization_type, :unpublished, name: "Hidden")
      expect(described_class.published_names).to eq([ "For-profit" ])
    end

    it "falls back to the canonical defaults when none are published" do
      expect(described_class.published_names).to eq(OrganizationType::DEFAULT_NAMES)
    end
  end

  describe "associations" do
    it "nullifies the type on dependent organizations when destroyed" do
      type = create(:organization_type, :published)
      organization = create(:organization, organization_type: type)
      type.destroy
      expect(organization.reload.organization_type_id).to be_nil
    end
  end
end
