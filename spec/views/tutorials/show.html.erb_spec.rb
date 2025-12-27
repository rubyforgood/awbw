require 'rails_helper'

RSpec.describe "tutorials/show", type: :view do
  let(:admin) { create(:user, :admin) }

  before(:each) do
    sign_in admin

    assign(:tutorial, Tutorial.create!(
      title: "Title",
      body: "MyText",
      featured: false,
      published: false,
      position: 2,
      youtube_url: "Youtube Url"
    ).decorate)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Title/)
    expect(rendered).to match(/MyText/)
  end
end
