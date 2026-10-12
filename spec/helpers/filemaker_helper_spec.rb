require "rails_helper"

RSpec.describe FilemakerHelper, type: :helper do
  let(:archive_viewer) { true }

  before do
    allow(helper).to receive(:allowed_to?).with(:show?, :fm_archive).and_return(archive_viewer)
  end

  describe "#filemaker_code_links" do
    let(:person) { build(:person, filemaker_code: "00006, 00012") }

    before { FmRolodex.create!(fm_id: "00006") }

    it "links each code the archive holds to its archive table" do
      html = helper.filemaker_code_links(person, label: "Rolodex")

      expect(html).to include(%(href="#{fm_archive_path("00006", table: "rolodexes")}"))
      expect(html).to include("Rolodex 00006")
    end

    it "shows just the label when the record carries a single code" do
      html = helper.filemaker_code_links(build(:person, filemaker_code: "00006"), label: "Rolodex")

      expect(html).to include(">Rolodex</a>")
      expect(html).not_to include("Rolodex 00006")
    end

    it "marks a code the archive has no row for instead of linking it" do
      html = helper.filemaker_code_links(person)

      expect(html).not_to include(fm_archive_path("00012", table: "rolodexes"))
      expect(html).to include(%(title="No FileMaker archive record for 00012"))
    end

    it "returns nothing for a record without codes" do
      expect(helper.filemaker_code_links(build(:person, filemaker_code: nil))).to be_nil
    end

    context "when the viewer can't open the archive" do
      let(:archive_viewer) { false }

      it "renders nothing" do
        expect(helper.filemaker_code_links(person)).to be_nil
      end
    end
  end

  describe "#filemaker_code_hint" do
    before { FmRolodex.create!(fm_id: "00006") }

    it "lists each code as an archive link" do
      html = helper.filemaker_code_hint(build(:person, filemaker_code: "00006"))

      expect(html).to include("In the archive:")
      expect(html).to include(%(href="#{fm_archive_path("00006", table: "rolodexes")}"))
      expect(html).to include("00006</a>")
    end

    it "returns nothing for a record without codes" do
      expect(helper.filemaker_code_hint(build(:person, filemaker_code: nil))).to be_nil
    end
  end

  describe "#filemaker_organization_links" do
    let(:organization) { build(:organization, filemaker_code: "P2775") }

    before do
      FmProject.create!(fm_id: "P2775", data: { "OrgID" => "ORG07206" })
      FmOrganization.create!(fm_id: "ORG07206")
    end

    it "links the FM organization each of the org's projects belongs to" do
      html = helper.filemaker_organization_links(organization, label: "FM organization")

      expect(html).to include(fm_archive_path("ORG07206", table: "organizations"))
      expect(html).to include(">FM organization</a>")
    end
  end
end
