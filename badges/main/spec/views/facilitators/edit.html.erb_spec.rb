require 'rails_helper'

RSpec.describe "facilitators/edit", type: :view do
  let(:facilitator) { create(:facilitator)}

  before do
    assign(:facilitator, facilitator)
    render
  end

  it "displays the edit heading" do
    expect(rendered).to match(/Edit Facilitator/)
  end

  it "has a form with the facilitator fields" do
    expect(rendered).to have_field('First name', with: facilitator.first_name)
    expect(rendered).to have_field('Last name', with: facilitator.last_name)
    expect(rendered).to have_field('Email', with: facilitator.email)
  end

  it "has a link to the show page" do
    expect(rendered).to have_link('Show', href: facilitator_path(facilitator))
  end

  it "has a link back to the index page" do
    expect(rendered).to have_link('Back', href: facilitators_path)
  end
end
