require 'rails_helper'

RSpec.describe "workshops/edit", type: :view do
  let(:user) { create(:user) }
  let(:super_user) { create(:user, super_user: true) }
  let(:workshop) { create(:workshop, user: user) }

  before(:each) do
    assign(:workshop, workshop)
    assign(:age_ranges, [])
    assign(:potential_series_workshops, [])
    assign(:windows_types, [])
    assign(:workshop_ideas, [])
    assign(:categories_grouped, {})
    assign(:sectors, [])
  end

  context "when user is a super_user" do
    before do
      allow(view).to receive(:current_user).and_return(super_user)
      render
    end

    it "displays the edit form" do
      expect(rendered).to match(/Edit Workshop/)
    end

    it "displays the View button" do
      expect(rendered).to have_link("View", href: workshop_path(workshop))
    end

    it "displays the Delete button" do
      expect(rendered).to have_link("Delete", href: workshop_path(workshop))
    end
  end

  context "when user is not a super_user" do
    before do
      allow(view).to receive(:current_user).and_return(user)
      render
    end

    it "does not display the Delete button" do
      expect(rendered).not_to have_link("Delete", href: workshop_path(workshop))
    end
  end
end
