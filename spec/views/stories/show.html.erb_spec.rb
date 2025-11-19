require 'rails_helper'

RSpec.describe "stories/show", type: :view do
  let(:user) { create(:user) }
  let(:story) { create(:story, created_by: user, updated_by: user,
                       body: "MyBody", youtube_url: "Youtube_url") }

  before(:each) do
    sign_in user
    allow(view).to receive(:current_user).and_return(user)
    assign(:story, story)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(story.project.name)
    expect(rendered).to match(story.workshop.name)
    expect(rendered).to match(/MyBody/)
    expect(rendered).to match(user.full_name)
  end
end
