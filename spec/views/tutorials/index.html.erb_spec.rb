require 'rails_helper'

RSpec.describe "tutorials/index", type: :view do
  let(:admin) { create(:user, :admin) }

  before(:each) do
    sign_in admin

    Tutorial.create!(
      title: "Title1",
      body: "MyText",
      featured: false,
      published: false,
      position: 2,
      youtube_url: "Youtube Url"
    )
    Tutorial.create!(
      title: "Title2",
      body: "MyText",
      featured: false,
      published: false,
      position: 2,
      youtube_url: "Youtube Url"
    )
    assign(:tutorials, Tutorial.all.decorate)
    assign(:sectors, Sector.published.order(:name))
    assign(:category_types, CategoryType.published.where(story_specific: false).order(:name).decorate)
  end

  it "renders a list of tutorials" do
    render
    expect(rendered).to match(/Title1/)
    expect(rendered).to match(/Title2/)
  end
end
