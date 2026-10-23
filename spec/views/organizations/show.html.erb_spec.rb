require "rails_helper"

RSpec.describe "organizations/show", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:organization) { create(:organization, name: "Organization 1") }

  before do
    assign(:organization, organization)
    sign_in user
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "renders attributes" do
    expect(rendered).to match(organization.name)
  end

  context "with affiliations" do
    let(:person) { create(:person, first_name: "Amy", last_name: "User") }

    before do
      create(:affiliation, person: person, organization: organization, title: "Director")
      create(:affiliation, person: person, organization: organization, title: "Facilitator")
      assign(:organization, organization.reload)
      render
    end

    it "groups multiple affiliations for the same person into one button" do
      # name appears twice per button (display text + title attr), so 2 = one button
      expect(rendered.scan("Amy User").count).to eq(2)
    end

    it "shows combined titles as subtitle" do
      expect(rendered).to include("Facilitator")
      expect(rendered).to include("Director")
    end

    it "sorts facilitator titles first" do
      expect(rendered).to match(/Facilitator.*Director/)
    end
  end

  context "with people a viewer can't open" do
    let(:facilitator) { create(:person, first_name: "Fay", last_name: "Active") }
    let(:director) { create(:person, first_name: "Dee", last_name: "Director") }
    let(:lapsed) { create(:person, first_name: "Lee", last_name: "Lapsed") }
    let(:hidden) { create(:person, first_name: "Hal", last_name: "Hidden", profile_is_searchable: false) }

    before do
      create(:affiliation, person: facilitator, organization: organization)
      create(:affiliation, person: director, organization: organization, title: "Director")
      create(:affiliation, person: lapsed, organization: organization, end_date: 1.month.ago)
      create(:affiliation, person: hidden, organization: organization)
      assign(:organization, organization.reload)
      render
    end

    it "lists only active facilitators whose profile the viewer can open" do
      expect(rendered).to include(person_path(facilitator))
      expect(rendered).not_to include(person_path(director))
      expect(rendered).not_to include(person_path(lapsed))
      expect(rendered).not_to include(person_path(hidden))
    end

    context "when the viewer is an admin" do
      let(:user) { admin }

      it "lists every actively affiliated person, whatever their title" do
        expect(rendered).to include(person_path(facilitator))
        expect(rendered).to include(person_path(hidden))
        expect(rendered).to include(person_path(director))
        expect(rendered).not_to include(person_path(lapsed))
      end
    end
  end
end
