require 'rails_helper'

RSpec.describe "community_news/new", type: :view do
  before(:each) do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
    
    assign(:community_news, CommunityNews.new(
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
    ))
  end

  it "renders new community_news form" do
    render

    assert_select "form[action=?][method=?]", community_news_index_path, "post" do

      assert_select "input[name=?]", "community_news[title]"

      assert_select "textarea[name=?]", "community_news[body]"

      assert_select "input[name=?]", "community_news[youtube_url]"

      assert_select "input[name=?]", "community_news[published]"

      assert_select "input[name=?]", "community_news[featured]"

      assert_select "input[name=?]", "community_news[inactive]"

      assert_select "input[name=?]", "community_news[author]"

      assert_select "input[name=?]", "community_news[reference_url]"

      assert_select "input[name=?]", "community_news[project_id]"

      assert_select "input[name=?]", "community_news[windows_type_id]"

      assert_select "input[name=?]", "community_news[workshop_id]"

      assert_select "input[name=?]", "community_news[created_by_id]"

      assert_select "input[name=?]", "community_news[updated_by_id]"
    end
  end
end
