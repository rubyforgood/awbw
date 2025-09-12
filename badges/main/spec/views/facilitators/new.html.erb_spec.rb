require 'rails_helper'

RSpec.describe "facilitators/new", type: :view do
  let(:facilitator) { create(:facilitator)}

  before do
    assign(:facilitator, facilitator)
    render
  end

  it "displays the edit heading" do
    expect(rendered).to match(/New Facilitator/)
  end

  it "has a form with the facilitator fields" do
    expect(rendered).to have_field('First name')
    expect(rendered).to have_field('Last name')
    expect(rendered).to have_field('Email')
  end

  it "has a link back to the index page" do
    expect(rendered).to have_link('Back', href: facilitators_path)
  end
end
