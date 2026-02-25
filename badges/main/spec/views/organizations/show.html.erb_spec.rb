require "rails_helper"

RSpec.describe "organizations/show", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let!(:organization) { create(:organization, name: "Organization 1") }

  before do
    assign(:organization, organization)
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
end
