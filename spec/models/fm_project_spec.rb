require "rails_helper"

RSpec.describe FmProject do
  describe "#grouped_data" do
    it "clusters filled fields under their group headings in the listed order" do
      project = described_class.new(data: { "EnteredBy" => "Sample Staff", "CloseDate" => "", "City" => "Venice", "OrgID" => "ORG1", "ProjectName" => "Adult Windows" })

      expect(project.grouped_data).to eq(
        "Project" => { nil => { "ProjectName" => "Adult Windows" } },
        "Organization & mergers" => { nil => { "OrgID" => "ORG1" } },
        "Location" => { nil => { "City" => "Venice" } },
        "Record keeping" => { nil => { "EnteredBy" => "Sample Staff" } }
      )
    end

    it "groups every documented FileMaker field exactly once" do
      documented = File.read(Rails.root.join("app/models/fm_project.rb")).scan(/^#   (\w+)/).flatten
      grouped = described_class.flat_field_groups.values.flatten

      expect(grouped).to match_array(documented)
    end
  end
end
