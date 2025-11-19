require 'rails_helper'

RSpec.describe "stories/new", type: :view do
    let(:user) { create(:user) }

  before(:each) do
    assign(:story, Story.new)
    assign(:windows_types, [])
    assign(:workshops, [])
    assign(:projects, [])
    assign(:users, [])
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders new story form" do
    render

    assert_select "form[action=?][method=?]", stories_path, "post" do

      assert_select "select[name=?]", "story[windows_type_id]"

      assert_select "select[name=?]", "story[project_id]"

      assert_select "select[name=?]", "story[workshop_id]"

      assert_select "textarea[name=?]", "story[body]"

      assert_select "textarea[name=?]", "story[youtube_url]"

      # assert_select "input[name=?]", "story[permission_given]"
      #
      # assert_select "input[name=?]", "story[publish_preferences]"

      assert_select "select[name=?]", "story[created_by_id]"
    end
  end
end
