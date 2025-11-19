require 'rails_helper'

RSpec.describe "community_news/edit", type: :view do
  let(:admin) { create(:user, :admin) }

  let(:community_news) {
    CommunityNews.create!(
      title: "MyString",
      body: "MyText",
      youtube_url: "MyString",
      published: false,
      featured: false,
      author: create(:user),
      reference_url: "MyString",
      project: nil,
      windows_type: nil,
      created_by: create(:user),
      updated_by: create(:user),
    )
  }
  let(:windows_types) { create_list(:windows_type, 3) }

  before(:each) do
    sign_in admin
    allow(view).to receive(:current_user).and_return(admin)
    assign(:community_news, community_news)
    assign(:windows_types, windows_types)
  end

  it "renders the edit community_news form" do
    render

    assert_select "form[action=?][method=?]", community_news_path(community_news), "post" do

      assert_select "textarea[name=?]", "community_news[title]"

      assert_select "textarea[name=?]", "community_news[body]"

      assert_select "textarea[name=?]", "community_news[youtube_url]"

      assert_select "input[name=?]", "community_news[published]"

      assert_select "input[name=?]", "community_news[featured]"

      assert_select "select[name=?]", "community_news[author_id]"

      assert_select "textarea[name=?]", "community_news[reference_url]"

      assert_select "select[name=?]", "community_news[project_id]"

      assert_select "select[name=?]", "community_news[windows_type_id]"
    end
  end
end
