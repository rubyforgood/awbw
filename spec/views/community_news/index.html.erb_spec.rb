require 'rails_helper'

RSpec.describe "community_news/index", type: :view do
  before(:each) do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
    
    assign(:community_news, [
      CommunityNews.create!(
        title: "Title",
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
      ),
      CommunityNews.create!(
        title: "Title",
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
      )
    ])
  end

  it "renders a list of community_news" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Title".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Youtube Url".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Author".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Reference Url".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
