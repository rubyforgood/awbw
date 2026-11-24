require "rails_helper"

RSpec.describe FmPersonnel do
  describe "#grouped_data" do
    it "clusters filled fields under their group headings in the listed order" do
      personnel = described_class.new(data: { "Notes" => "Moved away", "Role" => "Leader", "Name" => "Archie Coded", "AgreementStatus" => "Signed", "ModifiedBy" => "Sample Staff", "EnteredBy" => "", "DateEntered" => "2019-03-30" })

      expect(personnel.grouped_data).to eq(
        "Facilitator affiliation" => { nil => { "Name" => "Archie Coded", "Role" => "Leader" } },
        "Agreement & updates" => { nil => { "AgreementStatus" => "Signed" } },
        "Notes" => { nil => { "Notes" => "Moved away" } },
        "Record keeping" => { nil => { "DateEntered" => "2019-03-30", "ModifiedBy" => "Sample Staff" } }
      )
    end

    it "groups every documented FileMaker field exactly once" do
      documented = File.read(Rails.root.join("app/models/fm_personnel.rb")).scan(/^#   (\w+)/).flatten
      grouped = described_class.flat_field_groups.values.flatten

      expect(grouped).to match_array(documented)
    end
  end
end
