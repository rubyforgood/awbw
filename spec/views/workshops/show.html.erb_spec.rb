require 'rails_helper'

RSpec.describe "workshops/show", type: :view do
  let(:user) { create(:user) }
  let(:super_user) { create(:user, super_user: true) }
  let(:workshop) { create(:workshop, user: user) }

  before(:each) do
    assign(:workshop, workshop.decorate)
  end

  context "when user is a super_user" do
    before do
      allow(view).to receive(:current_user).and_return(super_user)
      render
    end

    it "displays the Edit button" do
      expect(rendered).to have_link("Edit", href: edit_workshop_path(workshop))
    end
  end

  context "when user is not a super_user" do
    before do
      allow(view).to receive(:current_user).and_return(user)
      render
    end

    it "does not display the Edit button" do
      expect(rendered).not_to have_link("Edit", href: edit_workshop_path(workshop))
    end
  end
end
