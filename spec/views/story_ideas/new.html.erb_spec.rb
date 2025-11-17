require 'rails_helper'

RSpec.describe "story_ideas/new", type: :view do
    let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  before(:each) do
    assign(:story_idea, StoryIdea.new)
    assign(:windows_types, [])
    assign(:workshops, [])
    assign(:projects, [])
    assign(:users, [])
  end

  context "when current_user is a regular user" do
    before do
      allow(view).to receive(:current_user).and_return(user)
    end

    it "renders new story_idea form without created_by_id field" do
      render

      assert_select "form[action=?][method=?]", story_ideas_path, "post" do
        assert_select "select[name=?]", "story_idea[windows_type_id]"
        assert_select "select[name=?]", "story_idea[project_id]"
        assert_select "select[name=?]", "story_idea[workshop_id]"
        assert_select "textarea[name=?]", "story_idea[body]"
        assert_select "textarea[name=?]", "story_idea[youtube_url]"
        assert_select "input[name=?]", "story_idea[permission_given]"
        assert_select "select[name=?]", "story_idea[publish_preferences]"
      end
    end
  end
end
