require 'rails_helper'

RSpec.describe "community_news/new", type: :view do
  let(:admin) { create(:user, :admin) }

  before(:each) do
    sign_in admin
    allow(view).to receive(:current_user).and_return(admin)

    assign(:community_news, CommunityNews.new(
      title: "MyString",
      body: "MyText",
      youtube_url: "MyString",
      published: false,
      featured: false,
      author: create(:user),
      reference_url: "MyString",
      organization: nil,
      windows_type: nil,
      created_by: create(:user),
      updated_by: create(:user),
    ))

    assign(:authors, [
      [ "User 1", create(:user).id ],
      [ admin.full_name, admin.id ],
      [ "User 2", create(:user).id ]
    ])
  end

  it "renders new community_news form" do
    render

    assert_select "form[action=?][method=?]", community_news_index_path, "post" do
      assert_select "textarea[name=?]", "community_news[title]"

      assert_select "input[name=?][type=?]", "community_news[rhino_body]", "hidden"

      assert_select "textarea[name=?]", "community_news[youtube_url]"

      assert_select "input[name=?]", "community_news[published]"

      assert_select "input[name=?]", "community_news[featured]"

      assert_select "select[name=?]", "community_news[author_id]"

      assert_select "textarea[name=?]", "community_news[reference_url]"

      assert_select "select[name=?]", "community_news[organization_id]"
    end
  end

  it "defaults author_id to current_user" do
    assign(:community_news, CommunityNews.new())

    render

    assert_select "select[name=?]", "community_news[author_id]" do
      assert_select "option[selected=?][value=?]", "selected", admin.id.to_s
    end
  end
end
