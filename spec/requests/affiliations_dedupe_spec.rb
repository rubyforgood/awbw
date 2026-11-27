# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Affiliation dedupe", type: :request do
  let(:organization) { create(:organization, name: "Duplicate Org") }
  let(:person) { create(:person) }
  let(:other_person) { create(:person) }
  let!(:keep) { create(:affiliation, person: person, organization: organization, title: "Facilitator") }
  let!(:other_keep) { create(:affiliation, person: other_person, organization: organization, title: "Facilitator") }

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
