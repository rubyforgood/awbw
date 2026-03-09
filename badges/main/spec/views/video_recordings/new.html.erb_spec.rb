require "rails_helper"

RSpec.describe "video_recordings/new", type: :view do
  let(:admin) { create(:user, :admin) }

  before(:each) do
    sign_in admin

    assign(:video_recording, VideoRecording.new(
      title: "MyString",
      youtube_url: "MyString",
      featured: false,
      published: false,
      position: 1,
      is_instructional: false
    ).decorate)
    assign(:categories_grouped, Category.includes(:category_type).published.order(:position, :name)
      .group_by(&:category_type).select { |type, _| type.nil? || type.published? }
      .sort_by { |type, _| type&.name.to_s.downcase })
    assign(:sectors, Sector.published.order(:name))
  end

  it "renders new video recording form" do
    render

    assert_select "form[action=?][method=?]", video_recordings_path, "post" do
      assert_select "textarea[name=?]", "video_recording[title]"
      assert_select "input[name=?][type=?]", "video_recording[rhino_body]", "hidden"
      assert_select "input[name=?][type=checkbox]", "video_recording[published]"
      assert_select "input[name=?][type=checkbox]", "video_recording[featured]"
      assert_select "input[name=?]", "video_recording[position]"
      assert_select "textarea[name=?]", "video_recording[youtube_url]"
    end
  end
end
