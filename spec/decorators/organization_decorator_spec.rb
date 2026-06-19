require "rails_helper"

RSpec.describe OrganizationDecorator do
  describe ".program_status_classes" do
    it "maps each status to its pill classes, accepting symbols or model strings" do
      expect(described_class.program_status_classes(:new)).to include("green")
      expect(described_class.program_status_classes(:ongoing)).to include("blue")
      expect(described_class.program_status_classes(:reinstated)).to include("yellow")
      # Organization#program_status returns "Reinstate" (no trailing d).
      expect(described_class.program_status_classes("Reinstate")).to include("yellow")
    end

    it "uses yellow, not amber, for reinstated" do
      classes = described_class.program_status_classes(:reinstated)
      expect(classes).to include("yellow")
      expect(classes).not_to include("amber")
    end

    it "is nil for a blank or unknown status" do
      expect(described_class.program_status_classes(nil)).to be_nil
      expect(described_class.program_status_classes(:bogus)).to be_nil
    end
  end

  describe "#program_status_badge" do
    let(:organization) { create(:organization) }

    it "renders a single-letter badge with the full label as a tooltip" do
      badge = Capybara.string(organization.decorate.program_status_badge(:ongoing))
      expect(badge).to have_css("span[title='Ongoing']", text: "O")
    end

    it "defaults to the organization's own program status" do
      create(:affiliation, organization: organization, person: create(:person), title: "Facilitator")

      badge = Capybara.string(organization.reload.decorate.program_status_badge)
      expect(badge).to have_css("span[title='Ongoing']", text: "O")
    end

    it "is nil for a blank status" do
      expect(organization.decorate.program_status_badge(nil)).to be_nil
    end
  end
end
