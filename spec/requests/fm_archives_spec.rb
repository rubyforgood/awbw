require "rails_helper"

RSpec.describe "FM archives", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /fm_archives/:id" do
    let!(:rolodex) { FmRolodex.create!(fm_id: "ROL1", data: { "ID" => "ROL1" }) }
    let!(:funding) { FmFunding.create!(fm_id: "FND1", data: { "RecordID" => "FND1", "FunderID" => "ROL1" }) }

    it "lists a rolodex record's funding under related records" do
      get fm_archive_path(rolodex.fm_id, table: "rolodexes")

      expect(response.body).to include("Funding (1)", "table=fundings")
    end
  end

  describe "GET /fm_archives" do
    let!(:funding) { FmFunding.create!(fm_id: "FND1", data: { "RecordID" => "FND1" }) }

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
