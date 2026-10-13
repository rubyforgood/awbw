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

  describe "#phone_numbers and #addresses" do
    let(:rolodex) do
      described_class.create!(fm_id: "00901", data: { "PrimaryPhoneID" => "PH2", "PrimaryAddrsID" => "AD3", "WorksiteAddrsID" => "AD9" })
    end

    before do
      FmPhoneNumber.create!(fm_id: "PH1", data: { "RolodexID" => "00901" })
      FmPhoneNumber.create!(fm_id: "PH2", data: { "RolodexID" => "00901" })
      FmPhoneNumber.create!(fm_id: "PH5", data: { "RolodexID" => "00777" })
      FmAddress.create!(fm_id: "AD1", data: { "RolodexID" => "00901" })
      FmAddress.create!(fm_id: "AD3", data: { "RolodexID" => "00901" })
      FmAddress.create!(fm_id: "AD9", data: { "RolodexID" => "00777" })
    end

    it "lists every phone carrying this record's ID, primary first" do
      expect(rolodex.phone_numbers.map(&:fm_id)).to eq(%w[PH2 PH1])
    end

    it "lists primary, then worksite, then other addresses, including a worksite filed under someone else" do
      expect(rolodex.addresses.map(&:fm_id)).to eq(%w[AD3 AD9 AD1])
    end
  end

  it "leaves tables without field groups as one unlabeled group" do
    organization = FmOrganization.new(data: { "OrgName" => "Shelter" })

    expect(organization.grouped_data).to eq(nil => { "OrgName" => "Shelter" })
  end
end
