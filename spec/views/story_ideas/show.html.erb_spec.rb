require 'rails_helper'

RSpec.describe "story_ideas/show", type: :view do
    let(:user) { create(:user) }
  let(:story_idea) { create(:story_idea, created_by: user, updated_by: user, body: "MyBody", youtube_url: "Youtube_url") }

  before(:each) do
    assign(:story_idea, story_idea)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(story_idea.project.name)
    expect(rendered).to match(story_idea.workshop.name)
    expect(rendered).to match(/MyBody/)
    expect(rendered).to match(user.full_name)
  end
end
