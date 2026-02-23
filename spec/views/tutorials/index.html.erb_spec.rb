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

  it "renders the search filters and turbo frame" do
    render
    assert_select "turbo-frame#tutorials_results"
    assert_select "input[name=search]"
  end
end

RSpec.describe "tutorials/index_lazy", type: :view do
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
    assign(:tutorials, Tutorial.all.paginate(page: 1, per_page: 25).decorate)
  end

  it "renders the tutorial titles inside the turbo frame" do
    render
    assert_select "turbo-frame#tutorials_results"
    expect(rendered).to match(/Title1/)
    expect(rendered).to match(/Title2/)
  end
end
