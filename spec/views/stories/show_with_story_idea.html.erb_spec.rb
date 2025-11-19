require 'rails_helper'

RSpec.describe "stories/show", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:story_idea) { create(:story_idea, :with_story,
                            created_by: admin, updated_by: admin,
                            body: "MyBody", youtube_url: "Youtube_url") }
  let(:story) { story_idea.stories.first }

  before(:each) do
    sign_in admin
    allow(view).to receive(:current_user).and_return(admin)
    assign(:story, story)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(story_idea.project.name)
    expect(rendered).to match(story_idea.workshop.name)
    expect(rendered).to match(/MyBody/)
    expect(rendered).to match(story_idea.created_by.full_name)
  end
end
