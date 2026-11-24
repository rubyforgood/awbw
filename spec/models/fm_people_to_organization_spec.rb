require "rails_helper"

RSpec.describe FmPeopleToOrganization do
  describe "#grouped_data" do
    it "clusters filled fields under their group headings in the listed order" do
      people_to_organization = described_class.new(data: { "ModificationTimeStamp" => "2022-05-04 10:00:00", "DateEntered" => "2021-03-30 00:00:00", "Notes" => "", "Title" => "Case Manager" })

      expect(people_to_organization.grouped_data).to eq(
        "Affiliation" => { nil => { "Title" => "Case Manager" } },
        "Record keeping" => { nil => { "DateEntered" => "2021-03-30 00:00:00", "ModificationTimeStamp" => "2022-05-04 10:00:00" } }
      )
    end

    it "groups every documented FileMaker field exactly once" do
      documented = File.read(Rails.root.join("app/models/fm_people_to_organization.rb")).scan(/^#   (\w+)/).flatten
      grouped = described_class.flat_field_groups.values.flatten

      expect(grouped).to match_array(documented)
    end
  end
end
