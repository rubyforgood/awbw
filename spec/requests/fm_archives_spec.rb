require "rails_helper"

RSpec.describe "FM archives", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET /fm_archives/:id" do
    before { sign_in admin }

    context "with related records" do
      let!(:rolodex) { FmRolodex.create!(fm_id: "ROL1", data: { "ID" => "ROL1" }) }
      let!(:funding) { FmFunding.create!(fm_id: "FND1", data: { "RecordID" => "FND1", "FunderID" => "ROL1" }) }

      it "lists a rolodex record's funding under related records" do
        get fm_archive_path(rolodex.fm_id, table: "rolodexes")

        expect(response.body).to include("Funding (1)", "table=fundings")
      end
    end

    it "shows a rolodex record's fields under group headings, most important first" do
      FmRolodex.create!(fm_id: "00006", data: { "ID" => "00006", "Comments" => "Met at training", "LastName" => "Archer" })

      get fm_archive_path("00006", table: "rolodexes")

      expect(response.body).to match(/Identity.*LastName.*Notes.*Comments.*Record keeping/m)
    end

    it "lists a rolodex record's phones and addresses in their own card" do
      FmRolodex.create!(fm_id: "00006", data: { "ID" => "00006", "EMail" => "abe@example.com", "PrimaryPhoneID" => "PH1" })
      FmPhoneNumber.create!(fm_id: "PH1", data: { "RolodexID" => "00006", "PhoneType" => "Work", "PhoneNumber" => "(213) 555-0101" })
      FmAddress.create!(fm_id: "AD1", data: { "RolodexID" => "00006", "AddrsLine1" => "88 Rose Ave", "AddrsCity" => "Venice" })

      get fm_archive_path("00006", table: "rolodexes")

      expect(response.body).to match(/Phones &amp; addresses.*Phone numbers \(1\).*\(213\) 555-0101.*Primary.*Addresses \(1\).*88 Rose Ave, Venice.*Record keeping/m)
      expect(response.body).to include("table=phone_numbers", "table=addresses")
      expect(response.body).to match(%r{Work\s*<span[^>]*>PH1</span>})
    end

    it "lists every field and association a rolodex record can hold below its cards" do
      FmRolodex.create!(fm_id: "00006", data: { "ID" => "00006" })

      get fm_archive_path("00006", table: "rolodexes")

      expect(response.body).to match(/Record keeping.*Available fields &amp; associations.*FacilitatorSinceYear.*OrgID.*Organizations.*Workshops \(Authored\).*AuthorID/m)
    end

    it "hides blank fields from the cards but keeps them, grayed, in the field reference" do
      FmRolodex.create!(fm_id: "00006", data: { "ID" => "00006", "LastName" => "Archer", "MiddleName" => "", "zcSort" => "" })

      get fm_archive_path("00006", table: "rolodexes")

      cards, reference = response.body.split("Available fields &amp; associations")
      expect(cards).to include("LastName")
      expect(cards).not_to include("MiddleName", "zcSort")
      expect(reference).to match(/text-gray-400">MiddleName</)
      expect(reference).to match(/text-gray-700">LastName</)
      expect(reference).to match(/Other fields.*zcSort/m)
    end

    it "strikes through a linked ID with no archive record, and links the rest" do
      FmRolodex.create!(fm_id: "00006", data: { "ID" => "00006", "PrimaryAddrsID" => "74999", "PrimaryPhoneID" => "75001" })
      FmPhoneNumber.create!(fm_id: "75001")

      get fm_archive_path("00006", table: "rolodexes")

      expect(response.body).to match(%r{<span[^>]*line-through[^>]*title="No FM record found"[^>]*>74999</span>})
      expect(response.body).to include(fm_archive_path("75001", table: "phone_numbers"))
      expect(response.body).not_to include(fm_archive_path("74999", table: "addresses"))
    end

    it "leaves the field reference off tables without field groups" do
      FmProject.create!(fm_id: "P2775")

      get fm_archive_path("P2775", table: "projects")

      expect(response.body).not_to include("Available fields")
    end

    it "links back to the portal people carrying the archive code" do
      FmRolodex.create!(fm_id: "00006")
      person = create(:person, first_name: "Archie", last_name: "Coded", filemaker_code: "00012, 00006")
      create(:person, filemaker_code: "000066")

      get fm_archive_path("00006", table: "rolodexes")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person_path(person))
      expect(response.body).to include("Archie Coded")
      expect(response.body.scan(%r{href="/people/\d+"}).size).to eq(1)
    end

    it "links an archived project back to its portal organization" do
      FmProject.create!(fm_id: "P2775")
      organization = create(:organization, filemaker_code: "P2775")

      get fm_archive_path("P2775", table: "projects")

      expect(response.body).to include(organization_path(organization))
    end

    it "links an archived FM organization back to the portal organization carrying its code" do
      FmOrganization.create!(fm_id: "ORG00023")
      organization = create(:organization, filemaker_code: "ORG00023")
      create(:organization, filemaker_code: "P00023")

      get fm_archive_path("ORG00023", table: "organizations")

      expect(response.body).to include(organization_path(organization))
      expect(response.body.scan(%r{href="/organizations/\d+"}).size).to eq(1)
    end

    it "links an archived FM organization back to the portal organizations its projects belong to" do
      FmOrganization.create!(fm_id: "ORG07206")
      FmProject.create!(fm_id: "P2775", data: { "OrgID" => "ORG07206" })
      FmProject.create!(fm_id: "P2776", data: { "OrgID" => "ORG07206" })
      FmProject.create!(fm_id: "P9000", data: { "OrgID" => "ORG09999" })
      via_project = create(:organization, filemaker_code: "P2775")
      via_both = create(:organization, filemaker_code: "P2776, ORG07206")
      create(:organization, filemaker_code: "P9000")

      get fm_archive_path("ORG07206", table: "organizations")

      expect(response.body).to include(organization_path(via_project), organization_path(via_both))
      expect(response.body.scan(%r{href="/organizations/\d+"}).size).to eq(2)
    end

    it "links an archived project back to the affiliations carrying its code" do
      FmProject.create!(fm_id: "P2775")
      affiliation = create(:affiliation, filemaker_code: "P2775")

      get fm_archive_path("P2775", table: "projects")

      expect(response.body).to include(edit_affiliation_path(affiliation))
    end

    it "links an archived personnel row back to its portal affiliation" do
      FmPersonnel.create!(fm_id: "PS9999")
      affiliation = create(:affiliation, filemaker_code: "PS9999")

      get fm_archive_path("PS9999", table: "personnels")

      expect(response.body).to include(edit_affiliation_path(affiliation))
      expect(response.body).to include(ERB::Util.html_escape("#{affiliation.person.full_name} at #{affiliation.organization.name}"))
    end

    it "links an archived payment back to its portal payment" do
      FmPayment.create!(fm_id: "D29186")
      person = create(:person)
      payment = create(:payment, person:, amount_cents: 15_000, filemaker_code: "D29186")

      get fm_archive_path("D29186", table: "payments")

      expect(response.body).to include(payment_path(payment))
      expect(response.body).to include("$150 from #{ERB::Util.html_escape(person.name)}")
    end

    it "links an archived workshop back to its portal workshop" do
      FmWorkshop.create!(fm_id: "W0123")
      workshop = create(:workshop, filemaker_code: "W0123")

      get fm_archive_path("W0123", table: "workshops")

      expect(response.body).to include(workshop_path(workshop))
      expect(response.body).to include(ERB::Util.html_escape(workshop.title))
    end

    it "omits the portal section when nothing carries the code" do
      FmRolodex.create!(fm_id: "00006")

      get fm_archive_path("00006", table: "rolodexes")

      expect(response.body).not_to include("In the portal")
    end
  end

  describe "GET /fm_archives/:id as a non-admin" do
    it "is not allowed" do
      FmRolodex.create!(fm_id: "00006")
      sign_in create(:user)

      get fm_archive_path("00006", table: "rolodexes")

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /fm_archives" do
    let!(:funding) { FmFunding.create!(fm_id: "FND1", data: { "RecordID" => "FND1" }) }

    before { sign_in admin }

    it "lists funding records at the table name a funding record's back link uses" do
      get fm_archives_path(table: FmFunding.table_name.delete_prefix("fm_"))

      expect(response.body).to include(fm_archive_path("FND1", table: "fundings"))
    end

    it "renders each group with its tables" do
      get fm_archives_path

      expect(response).to have_http_status(:ok)
      FmArchivesController::TABLE_GROUPS.each do |group|
        expect(response.body).to include(CGI.escapeHTML(group[:label]))
      end
      expect(response.body).to include("People to organizations")
    end

    it "marks the selected table as the current page" do
      get fm_archives_path(table: "rolodexes")

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/aria-current="page"[^>]*>Rolodex</)
    end
  end

  describe "table references" do
    let(:tables) { FmArchivesController::TABLES }
    let(:models) { tables.values.pluck(:model) }

    it "keys every archive table by its database table name" do
      expect(tables.keys.map { |key| "fm_#{key}" }).to eq(models.map(&:table_name))
    end

    it "resolves every related-records and link target to an archive table" do
      table_names = models.map(&:table_name)
      targets = models.flat_map do |model|
        related = model.const_defined?(:HAS_MANY, false) ? model::HAS_MANY.keys : []
        links = %i[FM_LINKS CONTEXT_LINK_MAP PREFIX_LINK_MAP].flat_map { |c| model.const_defined?(c, false) ? model.const_get(c).values : [] }
        (related + links).compact.map { |target| [ model.name, target ] }
      end

      expect(targets.reject { |_, target| table_names.include?(target) }).to be_empty
    end

    it "lists every archive table in exactly one group" do
      grouped = FmArchivesController::TABLE_GROUPS.flat_map { |group| group[:tables] }

      expect(grouped).to match_array(tables.keys)
    end
  end
end
