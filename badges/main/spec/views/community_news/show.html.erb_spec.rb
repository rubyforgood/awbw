require 'rails_helper'

RSpec.describe "community_news/show", type: :view do
  let!(:adult_permission) { create(:permission, :adult) }
  let!(:children_permission) { create(:permission, :children) }
  let!(:combined_permission) { create(:permission, :combined) }

  let(:admin) { create(:user, :admin) }

  before(:each) do
    sign_in admin

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
    expect(rendered).to match(/Reference Url/)
  end
end
