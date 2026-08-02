require "rails_helper"

RSpec.describe OrganizationDecorator do
  describe "#affiliated_since_display" do
    let(:organization) { create(:organization) }

    it "is blank when there are no affiliations and no start date" do
      organization.update_column(:start_date, nil)
      expect(organization.decorate.affiliated_since_display).to eq("")
    end

    it "falls back to the org start_date when there are no affiliations" do
      organization.update_column(:start_date, Date.new(2015, 3, 1))
      expect(organization.decorate.affiliated_since_display).to eq("Mar 2015")
    end

    it "shows merged affiliation periods" do
      create(:affiliation, organization: organization, person: create(:person),
                           start_date: Date.new(2010, 1, 1), end_date: Date.new(2012, 6, 1))
      create(:affiliation, organization: organization, person: create(:person),
                           start_date: Date.new(2013, 1, 1), end_date: Date.new(2015, 6, 1))
      expect(organization.reload.decorate.affiliated_since_display).to eq("2010-2012, 2013-2015")
    end
  end

  describe "#program_since_display" do
    let(:organization) { create(:organization) }

    it "is blank when the org has never had a facilitator affiliation" do
      create(:affiliation, organization: organization, person: create(:person), title: "Volunteer", start_date: Date.new(2010, 1, 1))
      expect(organization.reload.decorate.program_since_display).to eq("")
    end

    it "shows merged facilitator-affiliation periods, ignoring non-facilitator ones" do
      create(:affiliation, organization: organization, person: create(:person), title: "Facilitator", start_date: Date.new(2015, 1, 1), end_date: Date.new(2018, 6, 1))
      create(:affiliation, organization: organization, person: create(:person), title: "Volunteer", start_date: Date.new(2005, 1, 1), end_date: nil)
      create(:affiliation, organization: organization, person: create(:person), title: "Facilitator", start_date: Date.new(2024, 2, 1), end_date: nil)
      expect(organization.reload.decorate.program_since_display).to eq("2015-2018, 2024")
    end
  end

  describe "#organization_status_label" do
    it "returns the stored status name" do
      org = create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Active"))
      expect(org.decorate.organization_status_label).to eq("Active")
    end

    it "renders Unknown as 'Never active'" do
      org = create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Unknown"))
      expect(org.decorate.organization_status_label).to eq("Never active")
    end

    it "renders a missing status as 'Never active'" do
      org = create(:organization)
      org.update_columns(organization_status_id: nil)
      expect(org.decorate.organization_status_label).to eq("Never active")
    end
  end

  describe "#organization_status_chip" do
    it "renders a pill with the label and its status color" do
      org = create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Formerly active"))
      chip = org.decorate.organization_status_chip
      expect(Capybara.string(chip)).to have_css("span", text: "Formerly active")
      expect(chip).to include("orange")
    end
  end

  describe "#program_since_chip" do
    it "shows the years in the org's status colour (Active → green)" do
      org = create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Active"))
      chip = org.decorate.program_since_chip("2021")
      expect(Capybara.string(chip)).to have_css("span", text: "2021")
      expect(chip).to include("green")
    end

    it "falls back to the status label (orange) when there are no facilitator years" do
      org = create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Formerly active"))
      chip = org.decorate.program_since_chip("")
      expect(Capybara.string(chip)).to have_css("span", text: "Formerly active")
      expect(chip).to include("orange")
    end
  end

  describe ".program_status_classes" do
    it "maps each status to its pill classes, accepting symbols or model strings" do
      expect(described_class.program_status_classes(:new)).to include("indigo")
      expect(described_class.program_status_classes(:ongoing)).to include("blue")
      expect(described_class.program_status_classes(:reinstated)).to include("purple")
      # Organization#program_status returns "Reinstate" (no trailing d).
      expect(described_class.program_status_classes("Reinstate")).to include("purple")
    end

    it "uses purple, not amber, for reinstated" do
      classes = described_class.program_status_classes(:reinstated)
      expect(classes).to include("purple")
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

  describe "#high_profile_icon" do
    it "renders a starred marker with a tooltip when the org is high-profile" do
      organization = create(:organization, high_profile: true)
      icon = Capybara.string(organization.decorate.high_profile_icon)
      expect(icon).to have_css("i.fa-gem[title='High-profile organization']")
    end

    it "is nil for an ordinary organization" do
      organization = create(:organization, high_profile: false)
      expect(organization.decorate.high_profile_icon).to be_nil
    end
  end

  describe "#facilitator_status_as_of" do
    let(:organization) { create(:organization) }
    let(:person) { create(:person) }
    let(:reference) { Date.new(2026, 6, 1) }

    it "is :new when there are no facilitator affiliations starting before the date" do
      expect(organization.decorate.facilitator_status_as_of(reference)).to eq(:new)
    end

    it "ignores facilitator affiliations that start on or after the date" do
      create(:affiliation, organization: organization, person: person, title: "Facilitator", start_date: reference)
      expect(organization.reload.decorate.facilitator_status_as_of(reference)).to eq(:new)
    end

    it "is :ongoing when an earlier facilitator affiliation is still active on the date" do
      create(:affiliation, organization: organization, person: person, title: "Facilitator", start_date: reference - 1.year, end_date: nil)
      expect(organization.reload.decorate.facilitator_status_as_of(reference)).to eq(:ongoing)
    end

    it "is :reinstated when earlier facilitator affiliations all ended before the date" do
      create(:affiliation, organization: organization, person: person, title: "Facilitator", start_date: reference - 2.years, end_date: reference - 1.year)
      expect(organization.reload.decorate.facilitator_status_as_of(reference)).to eq(:reinstated)
    end

    it "ignores non-facilitator affiliations" do
      create(:affiliation, organization: organization, person: person, title: "Volunteer", start_date: reference - 1.year, end_date: nil)
      expect(organization.reload.decorate.facilitator_status_as_of(reference)).to eq(:new)
    end
  end

  describe "#agency_type_option" do
    it "returns a recognized type unchanged" do
      organization = create(:organization, agency_type: "For-profit")
      expect(organization.decorate.agency_type_option).to eq("For-profit")
    end

    it "folds a legacy 'Other' label into the catch-all 'Other'" do
      organization = create(:organization, agency_type: "Other (please specify below)")
      expect(organization.decorate.agency_type_option).to eq("Other")
    end

    it "leaves a blank value blank" do
      organization = create(:organization, agency_type: "")
      expect(organization.decorate.agency_type_option).to eq("")
    end
  end
end
