require 'rails_helper'

RSpec.describe "stories/edit", type: :view do
    let(:user) { create(:user) }
  let(:story) { create(:story, created_by: user, updated_by: user, body: "MyBody", youtube_url: "Youtube_url") }

  before(:each) do
    assign(:story, story)
    assign(:windows_types, [])
    assign(:workshops, [])
    assign(:projects, [])
    assign(:users, [])
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders the edit story form" do
    render

    assert_select "form[action=?][method=?]", story_path(story), "post" do

      assert_select "select[name=?]", "story[windows_type_id]"

      assert_select "select[name=?]", "story[project_id]"

      assert_select "select[name=?]", "story[workshop_id]"

      assert_select "textarea[name=?]", "story[body]"

      assert_select "textarea[name=?]", "story[youtube_url]"

      # assert_select "input[name=?]", "story[publish_preferences]"

      assert_select "select[name=?]", "story[created_by_id]"
    end
  end
end
