require 'rails_helper'

RSpec.describe "story_ideas/new", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:organizations) { create_list(:organization, 2) }

  before(:each) do
    assign(:story_idea, StoryIdea.new)
    assign(:windows_types, [])
    assign(:workshops, [])
    assign(:organizations, organizations)
    assign(:users, [])
    assign(:sectors, [])
    assign(:story_population_categories, [])
    assign(:story_population_type, nil)
  end

  shared_examples "organization dropdown" do
    it "renders the organization select" do
      render

      assert_select "form[action=?][method=?]", story_ideas_path, "post" do
        assert_select "select[name=?]", "story_idea[organization_id]"
        assert_select "input[type=hidden][name=?]", "story_idea[organization_id]", count: 0
      end
    end
  end

  shared_examples "hidden organization field" do
    it "renders a hidden field instead of the organization dropdown" do
      render

      assert_select "form[action=?][method=?]", story_ideas_path, "post" do
        assert_select "input[type=hidden][name=?][value=?]", "story_idea[organization_id]", organizations.first.id.to_s
        assert_select "select[name=?]", "story_idea[organization_id]", count: 0
      end
    end
  end

  context "when current_user is a regular user" do
    before do
      allow(view).to receive(:current_user).and_return(user)
    end

    context "with multiple organizations" do
      include_examples "organization dropdown"
    end

    context "with one organization" do
      let(:organizations) { [create(:organization)] }

      include_examples "hidden organization field"
    end
  end

  context "when current_user is an admin" do
    before do
      allow(view).to receive(:current_user).and_return(admin)
    end

    context "with multiple organizations" do
      include_examples "organization dropdown"
    end

    context "with one organization" do
      let(:organizations) { [create(:organization)] }

      include_examples "hidden organization field"
    end
  end
end
