require 'rails_helper'

RSpec.describe "community_news/show", type: :view do
  before(:each) do
    assign(:community_news, CommunityNews.create!(
      title: "Title",
      body: "MyText",
      youtube_url: "Youtube Url",
      published: false,
      featured: false,
      inactive: false,
      author: "Author",
      reference_url: "Reference Url",
      project: nil,
      windows_type: nil,
      workshop: nil,
      created_by: nil,
      updated_by: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Title/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/Youtube Url/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(/Author/)
    expect(rendered).to match(/Reference Url/)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
  end
end
