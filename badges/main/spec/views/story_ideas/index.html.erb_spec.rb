require 'rails_helper'

RSpec.describe "story_ideas/index", type: :view do
    let(:user) { create(:user) }
  let(:story_idea1) { create(:story_idea, created_by: user, updated_by: user, title: "My story1", youtube_url: "Youtube_url1") }
  let(:story_idea2) { create(:story_idea, created_by: user, updated_by: user, title: "My story2", youtube_url: "Youtube_url2") }

  before(:each) do
    # Simulate a single page of paginated results
    assign(:story_ideas, paginated([story_idea1, story_idea2]))
  end

  it "renders a list of story_ideas" do
    render
    expect(rendered).not_to include(story_idea1.title, story_idea2.title)
    expect(rendered).to include(story_idea1.name, story_idea2.name)
  end

  it "renders a friendly message when no story_ideas exist" do
    assign(:story_ideas, paginated([]))
    render
    expect(rendered).to match(/No Story ideas found/)
  end
end
