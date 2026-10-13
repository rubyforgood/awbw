require "rails_helper"

RSpec.describe FmRolodex do
  describe "#grouped_data" do
    it "clusters fields under their group headings in the listed order" do
      rolodex = described_class.new(data: { "Comments" => "Met at training", "LastName" => "Archer", "EMail" => "abe@example.com", "FirstName" => "Abe" })

      expect(rolodex.grouped_data).to eq(
        "Identity" => { nil => { "FirstName" => "Abe", "LastName" => "Archer", "EMail" => "abe@example.com" } },
        "Notes" => { nil => { "Comments" => "Met at training" } }
      )
      expect(rolodex.grouped_data.dig("Identity", nil).keys).to eq(%w[FirstName LastName EMail])
    end

    it "splits a card into its subcards" do
      rolodex = described_class.new(data: { "Status" => "Active", "Title" => "Director", "Organization" => "Shelter" })

      expect(rolodex.grouped_data).to eq(
        "Organization & affiliations" => {
          "Organization" => { "Organization" => "Shelter" },
          "Job affiliation" => { "Title" => "Director" },
          "Facilitator affiliation" => { "Status" => "Active" }
        }
      )
    end

    it "trails fields no group names under other fields" do
      rolodex = described_class.new(data: { "zcFullName" => "Abe Archer", "ID" => "00901" })

      expect(rolodex.grouped_data).to eq(
        "Record keeping" => { nil => { "ID" => "00901" } },
        "Other fields" => { nil => { "zcFullName" => "Abe Archer" } }
      )
    end

    it "leaves out blank fields and the groups they empty" do
      rolodex = described_class.new(data: { "FirstName" => "Abe", "MiddleName" => "", "Comments" => nil, "zcFullName" => "" })

      expect(rolodex.grouped_data).to eq("Identity" => { nil => { "FirstName" => "Abe" } })
    end

    it "leaves the primary phone and address IDs to the lists below" do
      FmAddress.create!(fm_id: "AD1")
      rolodex = described_class.new(fm_id: "00901", data: { "PrimaryAddrsID" => "AD1", "MailingList" => "Yes" })

      expect(rolodex.grouped_data).to eq(
        "Phones & addresses" => { FmRolodex::ADDRESSES => {}, "Mailing list" => { "MailingList" => "Yes" } }
      )
    end

    it "keeps an empty phones subcard when the person has phones on file" do
      rolodex = described_class.create!(fm_id: "00901", data: { "PrimaryPhoneID" => "" })
      FmPhoneNumber.create!(fm_id: "PH1", data: { "RolodexID" => "00901" })

      expect(rolodex.grouped_data).to eq("Phones & addresses" => { FmRolodex::PHONES => {} })
    end

    it "groups every documented FileMaker field exactly once" do
      documented = File.read(Rails.root.join("app/models/fm_rolodex.rb")).scan(/^#   (\w+)/).flatten
      grouped = described_class.flat_field_groups.values.flatten

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

    it "stands in an unsaved placeholder for a primary ID the archive lacks" do
      rolodex.data["PrimaryPhoneID"] = "PH9"

      expect(rolodex.phone_numbers.map { |phone| [ phone.fm_id, phone.persisted? ] }).to eq([ [ "PH9", false ], [ "PH1", true ], [ "PH2", true ] ])
    end
  end

  it "leaves tables without field groups as one unlabeled group" do
    organization = FmOrganization.new(data: { "OrgName" => "Shelter" })

    expect(organization.grouped_data).to eq(nil => { nil => { "OrgName" => "Shelter" } })
  end
end
