require "rails_helper"

RSpec.describe "people/sections/_organization_people", type: :view do
  let(:person) { create(:person) }

  it "renders organization affiliations" do
    op = create(:organization_person, person: person)
    organization_people = person.organization_people.active.paginate(page: 1)

    render partial: "people/sections/organization_people",
           locals: { person: person, organization_people: organization_people }

    expect(rendered).to include(op.organization.name)
  end

  it "does not error when an organization_person has a nil organization" do
    op = create(:organization_person, person: person)
    allow(op).to receive(:organization).and_return(nil)

    organization_people = WillPaginate::Collection.create(1, 10, 1) { |pager| pager.replace([op]) }

    expect {
      render partial: "people/sections/organization_people",
             locals: { person: person, organization_people: organization_people }
    }.not_to raise_error
  end

  it "shows empty state when no affiliations exist" do
    organization_people = person.organization_people.active.paginate(page: 1)

    render partial: "people/sections/organization_people",
           locals: { person: person, organization_people: organization_people }

    expect(rendered).to include("No affiliations listed")
  end
end
