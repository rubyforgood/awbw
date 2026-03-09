require "rails_helper"

RSpec.describe "video_recordings/show", type: :view do
  let(:admin) { create(:user, :admin) }

  before(:each) do
    sign_in admin

    assign(:video_recording, VideoRecording.create!(
      title: "Title",
      youtube_url: "Youtube Url",
      featured: false,
      published: false,
      position: 2,
      is_instructional: false
    ).decorate)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Title/)
  end
end
