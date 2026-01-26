require 'rails_helper'

RSpec.describe "stories/index", type: :view do
  let(:user) { create(:user) }
  let(:story1) { create(:story, created_by: user, updated_by: user, title: "My story1", youtube_url: "Youtube_url1") }
  let(:story2) { create(:story, created_by: user, updated_by: user, title: "My story2", youtube_url: "Youtube_url2") }

  before(:each) do
    sign_in user
    allow(view).to receive(:turbo_frame_request?).and_return(true)
    assign(:stories,
           StoryDecorator.decorate_collection(paginated([ story1, story2 ])))
  end

  it "renders a list of stories" do
    render template: "stories/index_lazy"
    expect(rendered).to include(story1.title, story2.title)
  end

  it "renders a friendly message when no stories exist" do
    assign(:stories, paginated([]))
    render template: "stories/index_lazy"
    expect(rendered).to match(/No stories found/)
  end
end
