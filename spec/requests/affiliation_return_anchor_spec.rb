require "rails_helper"
# The eyebrow and the post-save redirect must agree, and both have to account for
# the Inactive tab: a row that has ended isn't on screen when the person editor
# opens, so linking to it would scroll to something hidden.
RSpec.describe "where the affiliation editor sends you back to", type: :request do
  let(:person) { create(:person) }
  let(:org) { create(:organization) }
  before { sign_in create(:user, :admin) }

  it "anchors to the row when active, and redirects there after save" do
    aff = create(:affiliation, person: person, organization: org, start_date: 1.year.ago.to_date)
    get edit_affiliation_path(aff, return_to: "person", origin_id: person.id)
    expect(response.body).to include("#affiliation_#{aff.id}")

    patch affiliation_path(aff, return_to: "person", origin_id: person.id), params: { affiliation: { title: "Counselor" } }
    expect(response).to redirect_to(edit_person_path(person, anchor: "affiliation_#{aff.id}"))
  end

  it "anchors to the section when inactive" do
    aff = create(:affiliation, person: person, organization: org,
                 start_date: 2.years.ago.to_date, end_date: 1.year.ago.to_date)
    get edit_affiliation_path(aff, return_to: "person", origin_id: person.id)
    expect(response.body).to include("#affiliations")
    expect(response.body).not_to include("#affiliation_#{aff.id}")

    patch affiliation_path(aff, return_to: "person", origin_id: person.id), params: { affiliation: { title: "Counselor" } }
    expect(response).to redirect_to(edit_person_path(person, anchor: "affiliations"))
  end

  it "anchors to the section when the save is what makes it inactive" do
    aff = create(:affiliation, person: person, organization: org, start_date: 1.year.ago.to_date)
    patch affiliation_path(aff, return_to: "person", origin_id: person.id),
          params: { affiliation: { end_date: 1.day.ago.to_date.to_s } }
    expect(response).to redirect_to(edit_person_path(person, anchor: "affiliations"))
  end
end
