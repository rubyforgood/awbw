require 'rails_helper'

RSpec.describe "community_news/index", type: :view do
  let(:admin) { create(:user, :admin) }

  let(:community_news1) { CommunityNews.create!(
    title: "Title1",
    body: "MyText",
    youtube_url: "Youtube Url",
    published: false,
    featured: false,
    author: create(:user),
    reference_url: "Reference Url",
    project: nil,
    windows_type: nil,
    created_by: create(:user),
    updated_by: create(:user),
    ) }
  let(:community_news2) { CommunityNews.create!(
    title: "Title2",
    body: "MyText",
    youtube_url: "Youtube Url",
    published: false,
    featured: false,
    author: create(:user),
    reference_url: "Reference Url",
    project: nil,
    windows_type: nil,
    created_by: create(:user),
    updated_by: create(:user),
    ) }

  before(:each) do
    sign_in admin
    assign(:community_news, paginated([community_news1, community_news2]))
  end

  it "renders a list of community_news" do
    render
    expect(rendered).to include(community_news1.title, community_news2.title)
  end

  it "renders a friendly message when no banners exist" do
    assign(:community_news, paginated([]))
    render
    expect(rendered).to match(/No community news yet/)
  end
end
