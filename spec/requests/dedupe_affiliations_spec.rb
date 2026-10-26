# frozen_string_literal: true

require "rails_helper"

# A merge moves the deleted record's affiliations onto the keeper wholesale, so
# when both records were affiliated with the same org the keeper ends up holding
# identical copies. The merge must fold them into one.
RSpec.describe "Dedupe — affiliations", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "folds identical affiliations when two people merge" do
    organization = create(:organization)
    keep = create(:person, first_name: "Jane", last_name: "Doe", email: "jane@real.test")
    delete_rec = create(:person, first_name: "Jane", last_name: "Doe", email: "jane2@real.test")
    create(:affiliation, person: keep, organization: organization, title: "Facilitator")
    create(:affiliation, person: delete_rec, organization: organization, title: "Facilitator")

    post dedupe_perform_people_path, params: { person_to_keep_id: keep.id, person_to_delete_id: delete_rec.id }

    expect(response).to redirect_to(dedupe_index_people_path)
    expect(keep.reload.affiliations.count).to eq(1)
  end

  it "folds a person's identical affiliations when two organizations merge" do
    person = create(:person)
    keep = create(:organization, name: "Keep Org")
    delete_rec = create(:organization, name: "Delete Org")
    create(:affiliation, person: person, organization: keep, title: "Facilitator")
    create(:affiliation, person: person, organization: delete_rec, title: "Facilitator")

    post dedupe_perform_organizations_path, params: { organization_to_keep_id: keep.id, organization_to_delete_id: delete_rec.id }

    expect(person.reload.affiliations.count).to eq(1)
  end
end
