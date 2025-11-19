require 'rails_helper'

RSpec.describe "stories/index", type: :view do
  let(:user) { create(:user) }
  let(:story1) { create(:story, created_by: user, updated_by: user, title: "MyStory1", youtube_url: "Youtube_url1") }
  let(:story2) { create(:story, created_by: user, updated_by: user, title: "MyStory2", youtube_url: "Youtube_url2") }

  before(:each) do
    sign_in user
    assign(:stories, paginated([story1, story2]))
  end

  it "renders a list of stories" do
    render
    expect(rendered).to include(story1.title, story2.title)
  end

  it "renders a friendly message when no stories exist" do
    assign(:stories, paginated([]))
    render
    expect(rendered).to match(/No Stories found/)
  end
end
