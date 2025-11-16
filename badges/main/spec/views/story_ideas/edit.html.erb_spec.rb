require 'rails_helper'

RSpec.describe "story_ideas/edit", type: :view do
    let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:story_idea) { create(:story_idea, created_by: user, updated_by: user, body: "MyBody", youtube_url: "Youtube_url") }

  before(:each) do
    assign(:story_idea, story_idea)
    assign(:windows_types, [])
    assign(:workshops, [])
    assign(:projects, [])
    assign(:users, [])
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  context "when current_user is a regular user" do
    it "renders the edit story_idea form without created_by_id field" do
      assert_select "form[action=?][method=?]", story_idea_path(story_idea), "post" do
        assert_select "select[name=?]", "story_idea[windows_type_id]"
        assert_select "select[name=?]", "story_idea[project_id]"
        assert_select "select[name=?]", "story_idea[workshop_id]"
        assert_select "textarea[name=?]", "story_idea[body]"
        assert_select "textarea[name=?]", "story_idea[youtube_url]"
        assert_select "select[name=?]", "story_idea[publish_preferences]"
      end
    end

    it "does not render promote to story button" do
      expect(rendered).not_to have_link("Promote to Story")
    end
  end

  context "when current_user is an admin" do
    before do
      allow(view).to receive(:current_user).and_return(admin)
      render
    end

    it "renders promote to story button" do
      expect(rendered).to have_link("Promote to Story")
    end
  end
end
