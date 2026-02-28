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

    expect(rendered).to include("No affiliations listed").or include("No active affiliations")
  end

  it "groups multiple affiliations with the same organization into one button" do
    org = create(:organization, name: "Shared Org")
    create(:affiliation, person: person, organization: org, title: "Director")
    create(:affiliation, person: person, organization: org, title: "Facilitator")
    affiliations = person.affiliations.active.paginate(page: 1)

    render partial: "people/sections/affiliations",
           locals: { person: person, affiliations: affiliations }

    # name appears twice per button (display text + title attr), so 2 = one button
    expect(rendered.scan("Shared Org").count).to eq(2)
  end

  it "shows combined titles as subtitle when same org has multiple affiliations" do
    org = create(:organization, name: "Shared Org")
    create(:affiliation, person: person, organization: org, title: "Director")
    create(:affiliation, person: person, organization: org, title: "Facilitator")
    affiliations = person.affiliations.active.paginate(page: 1)

    render partial: "people/sections/affiliations",
           locals: { person: person, affiliations: affiliations }

    expect(rendered).to include("Facilitator")
    expect(rendered).to include("Director")
  end

  it "sorts facilitator titles first in subtitle" do
    org = create(:organization, name: "Shared Org")
    create(:affiliation, person: person, organization: org, title: "Zebra Role")
    create(:affiliation, person: person, organization: org, title: "Art Facilitator")
    affiliations = person.affiliations.active.paginate(page: 1)

    render partial: "people/sections/affiliations",
           locals: { person: person, affiliations: affiliations }

    expect(rendered).to match(/Art Facilitator.*Zebra Role/)
  end
end
