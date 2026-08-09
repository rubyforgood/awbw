require "rails_helper"

RSpec.describe AttendeesActiveFilters do
  def chips_for(params)
    described_class.new(ActionController::Parameters.new(params)).chips
  end

  it "returns nothing when no drill-in filter is applied" do
    expect(chips_for(contact_info: "ada", sector: "3", state: "OR")).to eq([])
  end

  it "counts the people behind a registrant_ids drill-in" do
    expect(chips_for(registrant_ids: "4-9-12")).to eq([ { param: "registrant_ids", label: "3 selected people" } ])
  end

  it "labels an organization by name and drops it when the org is gone" do
    org = create(:organization, name: "Wellness Collective")

    expect(chips_for(organization_id: org.id)).to eq([ { param: "organization_id", label: "Organization: Wellness Collective" } ])
    expect(chips_for(organization_id: org.id + 1)).to eq([])
  end

  it "labels the category-backed drill-ins by their category name" do
    age = create(:category, name: "Teens (13-17)")
    experience = create(:category, name: "Domestic violence")
    setting = create(:category, name: "Shelter")

    expect(chips_for(age_group: age.id).first[:label]).to eq("Age group: Teens (13-17)")
    expect(chips_for(life_experience: experience.id).first[:label]).to eq("Life experience: Domestic violence")
    expect(chips_for(setting: setting.id).first[:label]).to eq("Setting: Shelter")
  end

  it "labels the literal-value drill-ins" do
    expect(chips_for(country: "Canada").first[:label]).to eq("Country: Canada")
    expect(chips_for(school_district: "PPS").first[:label]).to eq("School district: PPS")
    expect(chips_for(org_city: "Austin, TX").first[:label]).to eq("Org city: Austin, TX")
  end

  it "labels the yes/no scholarship and CE drill-ins" do
    expect(chips_for(scholarship: "yes").first[:label]).to eq("Scholarship recipients")
    expect(chips_for(scholarship: "no").first[:label]).to eq("No scholarship")
    expect(chips_for(ce: "yes").first[:label]).to eq("Continuing education")
    expect(chips_for(ce: "no").first[:label]).to eq("No continuing education")
  end

  it "emits chips in CHIP_PARAMS order regardless of param order" do
    params = chips_for(scholarship: "yes", country: "Canada", registrant_ids: "1-2")
    expect(params.map { |c| c[:param] }).to eq(%w[ registrant_ids country scholarship ])
  end
end
