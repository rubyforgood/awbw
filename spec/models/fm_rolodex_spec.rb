require "rails_helper"

RSpec.describe FmRolodex do
  describe "#grouped_data" do
    it "clusters fields under their group headings in the listed order" do
      rolodex = described_class.new(data: { "Comments" => "Met at training", "LastName" => "Archer", "EMail" => "abe@example.com", "FirstName" => "Abe" })

      expect(rolodex.grouped_data).to eq(
        "Identity" => { "FirstName" => "Abe", "LastName" => "Archer" },
        "Contact" => { "EMail" => "abe@example.com" },
        "Notes" => { "Comments" => "Met at training" }
      )
      expect(rolodex.grouped_data["Identity"].keys).to eq(%w[FirstName LastName])
    end

    it "trails fields no group names under other fields" do
      rolodex = described_class.new(data: { "zcFullName" => "Abe Archer", "ID" => "00901" })

      expect(rolodex.grouped_data).to eq(
        "Record keeping" => { "ID" => "00901" },
        "Other fields" => { "zcFullName" => "Abe Archer" }
      )
    end

    it "groups every documented FileMaker field exactly once" do
      documented = File.read(Rails.root.join("app/models/fm_rolodex.rb")).scan(/^#   (\w+)/).flatten
      grouped = described_class::FIELD_GROUPS.values.flatten

      expect(grouped).to match_array(documented)
    end
  end

  it "leaves tables without field groups as one unlabeled group" do
    organization = FmOrganization.new(data: { "OrgName" => "Shelter" })

    expect(organization.grouped_data).to eq(nil => { "OrgName" => "Shelter" })
  end
end
