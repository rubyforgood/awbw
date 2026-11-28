# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Affiliation dedupe", type: :request do
  let(:organization) { create(:organization, name: "Duplicate Org") }
  let(:person) { create(:person) }
  let(:other_person) { create(:person) }
  let!(:keep) { create(:affiliation, :facilitator, person: person, organization: organization) }
  let!(:other_keep) { create(:affiliation, :facilitator, person: other_person, organization: organization) }

  # A merge moves rows with update_all, so identical copies land without
  # Affiliation#skip_if_duplicate ever running; save without validation to match.
  def copy_of(original)
    original.dup.tap { |copy| copy.save!(validate: false) }
  end

  def sgid(record)
    record.to_sgid(for: AffiliationsController::DEDUPE_PURPOSE).to_s
  end

  before do
    copy_of(keep)
    2.times { copy_of(other_keep) }
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "lists people with duplicate affiliations" do
      get dedupe_index_affiliations_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.full_name, other_person.full_name, "Merge 1 duplicate", "Merge 2 duplicates")
      expect(response.body.scan(">Keep<").size).to eq(2)
      expect(response.body.scan(">Merge<").size).to eq(3)
    end

    describe "search" do
      def listed_names(query)
        get dedupe_index_affiliations_path, params: { query: query }
        [ person, other_person ].select { |someone| response.body.include?(someone.full_name) }
      end

      it "finds a person by name or FileMaker code" do
        person.update!(last_name: "Zephyrine")
        other_person.update!(filemaker_code: "P900")

        expect(listed_names("Zephyrine")).to eq([ person ])
        expect(listed_names("P900")).to eq([ other_person ])
      end

      it "finds an organization's people by its FileMaker code" do
        organization.update!(filemaker_code: "O700")

        expect(listed_names("O700")).to eq([ person, other_person ])
      end

      it "finds a person by any one affiliation's portal id or FileMaker code" do
        keep.update_column(:filemaker_code, "A55")

        expect(listed_names(other_keep.id.to_s)).to eq([ other_person ])
        expect(listed_names("A55")).to eq([ person ])
      end

      it "says when nothing matches" do
        get dedupe_index_affiliations_path, params: { query: "nobody-here" }

        expect(response.body).to include("No duplicate affiliations match that search.")
      end
    end

    it "keeps the search after a merge" do
      post dedupe_perform_affiliations_path, params: { person_sgid: sgid(person), query: "Duplicate" }

      expect(response).to redirect_to(dedupe_index_affiliations_path(query: "Duplicate"))
    end

    it "merges one person's duplicates" do
      post dedupe_perform_affiliations_path, params: { person_sgid: sgid(person) }

      expect(response).to redirect_to(dedupe_index_affiliations_path)
      expect(flash[:notice]).to include("1 duplicate affiliation")
      expect(person.affiliations.reload).to eq([ keep ])
      expect(other_person.affiliations.count).to eq(3)
    end

    it "rejects a signed id minted for another purpose" do
      post dedupe_perform_affiliations_path, params: { person_sgid: person.to_sgid.to_s }

      expect(flash[:alert]).to include("Error merging affiliations")
      expect(person.affiliations.count).to eq(2)
    end
  end

  context "as a regular user" do
    before { sign_in create(:user) }

    it "denies the page and the merge" do
      get dedupe_index_affiliations_path
      expect(response).to redirect_to(root_path)

      post dedupe_perform_affiliations_path, params: { person_sgid: sgid(person) }
      expect(response).to redirect_to(root_path)
      expect(person.affiliations.count).to eq(2)
    end
  end
end
