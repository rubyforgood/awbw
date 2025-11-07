require 'rails_helper'

RSpec.describe "story_ideas/edit", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm)    { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:story_idea) { create(:story_idea, created_by: user, updated_by: user, body: "MyBody", youtube_url: "Youtube_url") }

  before(:each) do
    assign(:story_idea, story_idea)
    assign(:windows_types, [])
    assign(:workshops, [])
    assign(:projects, [])
    assign(:users, [])
  end

  context "when current_user is a regular user" do
    before do
      allow(view).to receive(:current_user).and_return(user)
    end

    it "renders the edit story_idea form without created_by_id field" do
      render

      assert_select "form[action=?][method=?]", story_idea_path(story_idea), "post" do
        assert_select "select[name=?]", "story_idea[windows_type_id]"
        assert_select "select[name=?]", "story_idea[project_id]"
        assert_select "select[name=?]", "story_idea[workshop_id]"
        assert_select "textarea[name=?]", "story_idea[body]"
        assert_select "input[name=?]", "story_idea[youtube_url]"
        assert_select "select[name=?]", "story_idea[publish_preferences]"
        assert_select "select[name=?]", "story_idea[created_by_id]", count: 0
      end
    end
  end

  context "when current_user is an admin" do
    before do
      allow(view).to receive(:current_user).and_return(admin)
    end

    it "renders the edit story_idea form with created_by_id field" do
      render

      assert_select "form[action=?][method=?]", story_idea_path(story_idea), "post" do
        assert_select "select[name=?]", "story_idea[created_by_id]", count: 1
      end
    end
  end
end
