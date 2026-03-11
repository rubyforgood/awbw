require 'rails_helper'

RSpec.describe "workshops/edit", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:workshop) { create(:workshop, created_by: user) }

  before(:each) do
    assign(:workshop, workshop)
    assign(:age_ranges, [])
    assign(:potential_series_workshops, [])
    assign(:windows_types, [])
    assign(:workshop_ideas, [])
    assign(:sectors, [])
    assign(:categories_grouped, [])
    assign(:age_range_comments, [])
  end

  context "when user is an admin" do
    before do
      allow(view).to receive(:current_user).and_return(admin)
      allow(view).to receive(:allowed_to?).with(:destroy?, workshop).and_return(true)
      allow(view).to receive(:allowed_to?).and_return(true)
      render
    end

    it "displays the edit form" do
      expect(rendered).to match(/Edit workshop/)
    end

    it "displays the View button" do
      expect(rendered).to have_link("View", href: workshop_path(workshop))
    end

    it "displays the Delete button" do
      expect(rendered).to have_link("Delete", href: workshop_path(workshop))
    end
  end

  context "when there are age range data comments" do
    let(:age_range_type) { create(:category_type, name: "AgeRange", published: true) }
    let(:category) { create(:category, name: "6-12", category_type: age_range_type, published: true) }
    let(:comment) { create(:comment, commentable: workshop, body: "[AGE_RANGE_DATA] Auto-applied age range categories: 6-12 from age_range: '6-12'.") }

    before do
      allow(view).to receive(:current_user).and_return(admin)
      allow(view).to receive(:allowed_to?).and_return(true)
      assign(:categories_grouped, [ [ age_range_type, [ category ] ] ])
      assign(:age_range_comments, [ comment ])
      render
    end

    it "displays the age range data comment with tag" do
      expect(rendered).to include("[AGE_RANGE_DATA]")
      expect(rendered).to include("Auto-applied age range categories: 6-12")
    end

    it "links the comment to the comments section" do
      expect(rendered).to have_link(href: "#comments-section")
    end
  end

  context "when user is not an admin" do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:allowed_to?).and_return(false)
      render
    end

    it "does not display the Delete button" do
      expect(rendered).not_to have_link("Delete", href: workshop_path(workshop))
    end
  end
end
