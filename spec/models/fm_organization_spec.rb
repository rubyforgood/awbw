require "rails_helper"

RSpec.describe FmOrganization do
  describe "#grouped_data" do
    it "clusters filled fields under their group headings in the listed order" do
      organization = described_class.new(data: { "Comments" => "Met at a conference", "Status" => "Active", "OrgName" => "Sample Shelter", "Hierarchy" => "Primary", "Website" => "" })

      expect(organization.grouped_data).to eq(
        "Organization" => { nil => { "OrgName" => "Sample Shelter", "Status" => "Active" } },
        "Hierarchy" => { nil => { "Hierarchy" => "Primary" } },
        "Notes" => { nil => { "Comments" => "Met at a conference" } }
      )
    end

    it "groups every documented FileMaker field exactly once" do
      documented = File.read(Rails.root.join("app/models/fm_organization.rb")).scan(/^#   (\w+)/).flatten
      grouped = described_class.flat_field_groups.values.flatten

      expect(grouped).to match_array(documented)
    end
  end
end
