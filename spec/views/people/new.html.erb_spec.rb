require 'rails_helper'

RSpec.describe "people/new", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:person) { create(:person) }

  before do
    assign(:person, person)
    allow(view).to receive(:current_user).and_return(admin)
    render
  end

  it "displays the edit heading" do
    expect(rendered).to match(/New person/)
  end

  it "has a form with the person fields" do
    # Name fields collapse to a summary by default, so they're present but not
    # visible until the section is expanded.
    expect(rendered).to have_field('First name', visible: :all)
    expect(rendered).to have_field('Last name', visible: :all)
    expect(rendered).to have_field('Pronouns', visible: :all)
  end

  it "has a link back to the index page" do
    expect(rendered).to have_link('Cancel', href: people_path)
  end
end
