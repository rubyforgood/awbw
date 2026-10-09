require 'rails_helper'

RSpec.describe "people/index", type: :view do
  let(:admin) { create(:user, :admin) }

  let(:person) { create(:person) }
  let(:person_2) { create(:person) }

  before(:each) do
    assign(:people, paginated([ person, person_2 ]))
    assign(:count_display, 2)
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders the skeleton loader" do
    render
    expect(rendered).to have_css("turbo-frame#people_results")
  end

  it "renders a list of people" do
    render template: "people/people_results"
    expect(rendered).to match(person.first_name)
    expect(rendered).to match(person_2.first_name)
  end
end
