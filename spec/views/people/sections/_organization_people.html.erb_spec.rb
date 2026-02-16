require "rails_helper"

RSpec.describe "people/sections/_affiliations", type: :view do
  let(:person) { create(:person) }

  it "renders organization affiliations" do
    op = create(:affiliation, person: person)
    affiliations = person.affiliations.active.paginate(page: 1)

    render partial: "people/sections/affiliations",
           locals: { person: person, affiliations: affiliations }

    expect(rendered).to include(op.organization.name)
  end

  it "does not error when an affiliation has a nil organization" do
    op = create(:affiliation, person: person)
    allow(op).to receive(:organization).and_return(nil)

    affiliations = WillPaginate::Collection.create(1, 10, 1) { |pager| pager.replace([ op ]) }

    expect {
      render partial: "people/sections/affiliations",
             locals: { person: person, affiliations: affiliations }
    }.not_to raise_error
  end

  it "shows empty state when no affiliations exist" do
    affiliations = person.affiliations.active.paginate(page: 1)

    render partial: "people/sections/affiliations",
           locals: { person: person, affiliations: affiliations }

    expect(rendered).to include("No affiliations listed")
  end
end
