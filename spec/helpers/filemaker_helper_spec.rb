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

    context "when only linked codes are wanted" do
      it "drops a code the archive has no row for" do
        html = helper.filemaker_code_links(person, label: "Rolodex", linked_only: true)

        expect(html).not_to include("00012")
        expect(html).not_to include("No FileMaker archive record")
      end

      it "names the one remaining link by its label alone" do
        html = helper.filemaker_code_links(person, label: "Rolodex", linked_only: true)

        expect(html).to include(">Rolodex</a>")
        expect(html).not_to include("Rolodex 00006")
      end

      it "returns nothing when no code has an archive row" do
        html = helper.filemaker_code_links(build(:person, filemaker_code: "00012"), label: "Rolodex", linked_only: true)

        expect(html).to be_nil
      end
    end

    context "when the viewer can't open the archive" do
      let(:archive_viewer) { false }

      it "renders nothing" do
        expect(helper.filemaker_code_links(person)).to be_nil
      end
    end

    context "with a record archived in more than one table" do
      let(:affiliation) { build(:affiliation, filemaker_code: "P2775, PS9999") }

      before do
        FmProject.create!(fm_id: "P2775")
        FmPersonnel.create!(fm_id: "PS9999")
      end

      it "links each code to whichever table holds it" do
        html = helper.filemaker_code_links(affiliation)

        expect(html).to include(fm_archive_path("P2775", table: "projects"))
        expect(html).to include(fm_archive_path("PS9999", table: "personnels"))
      end
    end
  end

  describe "#fm_archive_records" do
    it "finds the record an ID points at" do
      organization = FmOrganization.create!(fm_id: "ORG1")

      expect(helper.fm_archive_records("ORG1", "fm_organizations")).to eq([ organization ])
    end

    it "stands in an unsaved placeholder for an ID the archive lacks" do
      record = helper.fm_archive_records("ORG9", "fm_organizations").sole

      expect([ record.class, record.fm_id, record.persisted? ]).to eq([ FmOrganization, "ORG9", false ])
    end

    it "splits a list on line breaks and pilcrows, keeping its order and dropping repeats" do
      FmRolodex.create!(fm_id: "00902")

      records = helper.fm_archive_records("00902\r\n00901¶ 00903\v00902\n", "fm_rolodexes")

      expect(records.map(&:fm_id)).to eq(%w[00902 00901 00903])
      expect(records.map(&:persisted?)).to eq([ true, false, false ])
    end
  end

  describe "#fm_archive_id_tag" do
    it "links a record's ID to its archive page" do
      html = helper.fm_archive_id_tag(FmAddress.create!(fm_id: "74001"))

      expect(html).to match(%r{<a[^>]*href="#{Regexp.escape(fm_archive_path("74001", table: "addresses"))}"[^>]*>74001</a>})
    end

    it "strikes through an ID the archive has no record for" do
      html = helper.fm_archive_id_tag(FmAddress.new(fm_id: "74999"))

      expect(html).to include("line-through", %(title="No FM record found"), "74999")
      expect(html).not_to include("href")
    end
  end

  describe "#fm_archive_summary_tag" do
    it "links a record by its decorator's summary" do
      address = FmAddress.create!(fm_id: "74001", data: { "AddrsLine1" => "88 Rose Ave", "AddrsCity" => "Venice" })

      expect(helper.fm_archive_summary_tag(address)).to include(">88 Rose Ave, Venice</a>")
    end

    it "links a record without a decorator by its name" do
      organization = FmOrganization.create!(fm_id: "ORG1", data: { "OrgName" => "Sample Shelter" })

      expect(helper.fm_archive_summary_tag(organization)).to include(">Sample Shelter</a>")
    end

    it "notes a record the archive lacks as not found" do
      expect(helper.fm_archive_summary_tag(FmOrganization.new(fm_id: "ORG9"))).to include("Not found in FM data")
    end
  end

  describe "#fm_portal_counterpart_name" do
    let(:rolodex) { FmRolodex.new }

    it "names the portal counterpart when it differs from the archive's name" do
      expect(helper.fm_portal_counterpart_name(rolodex, "fm_personnels", "Personnel")).to eq("Affiliations")
    end

    it "skips a counterpart the archive's label already leads with, ignoring case" do
      expect(helper.fm_portal_counterpart_name(rolodex, "fm_workshop_logs", "Workshop Logs")).to be_nil
      expect(helper.fm_portal_counterpart_name(rolodex, "fm_workshops", "Workshops Authored")).to be_nil
    end

    it "skips a table without a portal counterpart" do
      expect(helper.fm_portal_counterpart_name(rolodex, "fm_volunteers", "Volunteer Records")).to be_nil
    end
  end

  describe "#fm_related_table_highlight" do
    let(:rolodex) { FmRolodex.new }

    it "colors a table the portal has its own records for orange" do
      expect(helper.fm_related_table_highlight(rolodex, "fm_workshop_logs")).to include("bg-orange-100")
    end

    it "leaves a table with no portal counterpart uncolored" do
      expect(helper.fm_related_table_highlight(rolodex, "fm_volunteers")).to be_nil
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

    it "drops an FM organization the archive has no row for when only linked ones are wanted" do
      FmProject.create!(fm_id: "P9000", data: { "OrgID" => "ORG99999" })

      html = helper.filemaker_organization_links(build(:organization, filemaker_code: "P9000"), label: "FM organization", linked_only: true)

      expect(html).to be_nil
    end

    it "links an FM organization the org carries directly, alongside its projects' FM organizations" do
      FmOrganization.create!(fm_id: "ORG00023")

      html = helper.filemaker_organization_links(build(:organization, filemaker_code: "P2775, ORG00023"), label: "FM organization")

      expect(html).to include(fm_archive_path("ORG00023", table: "organizations"))
      expect(html).to include(fm_archive_path("ORG07206", table: "organizations"))
    end

    it "links the FM organization once when the org carries it and one of its projects sits under it" do
      html = helper.filemaker_organization_links(build(:organization, filemaker_code: "P2775, ORG07206"), label: "FM organization")

      expect(html.scan(fm_archive_path("ORG07206", table: "organizations")).size).to eq(1)
    end
  end

  describe "#filemaker_project_links" do
    it "links only the org's FM project codes" do
      FmProject.create!(fm_id: "P2775")
      FmOrganization.create!(fm_id: "ORG00023")

      html = helper.filemaker_project_links(build(:organization, filemaker_code: "P2775, ORG00023"), label: "FM project", linked_only: true)

      expect(html).to include(fm_archive_path("P2775", table: "projects"))
      expect(html).not_to include("ORG00023")
      expect(html).to include(">FM project</a>")
    end
  end

  describe "organization codes" do
    it "match the full code, so a bare number reaches neither a project nor an FM organization" do
      FmProject.create!(fm_id: "P00023")
      FmOrganization.create!(fm_id: "ORG00023")

      html = helper.filemaker_code_links(build(:organization, filemaker_code: "00023, P00023, ORG00023"))

      expect(html).to include(fm_archive_path("P00023", table: "projects"))
      expect(html).to include(fm_archive_path("ORG00023", table: "organizations"))
      expect(html).to include(%(title="No FileMaker archive record for 00023"))
    end
  end
end
