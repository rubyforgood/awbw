require 'rails_helper'

RSpec.describe "community_news/show", type: :view do
  before(:each) do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
    
    assign(:community_news, CommunityNews.create!(
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
