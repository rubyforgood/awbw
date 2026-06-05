require 'rails_helper'

RSpec.describe "stories/show", type: :view do
  let(:user) { create(:user, :with_person) }
  let(:story) { create(:story, created_by: user, updated_by: user,
                       rhino_body: "<p>MyBody</p>", youtube_url: "Youtube_url") }

  before(:each) do
    sign_in user
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:allowed_to?).and_return(true)
    assign(:story, story.decorate)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(story.organization.name)
    expect(rendered).to match(story.workshop.name)
    expect(rendered).to match(/MyBody/)
    expect(rendered).to match(story.author_credit)
  end

  context "with primary and gallery images" do
    let(:story_with_images) do
      created = create(:story, created_by: user, updated_by: user)
      create(:primary_asset, :with_file, owner: created)
      create(:gallery_asset, :with_file, owner: created)
      created.reload
    end

    before do
      assign(:story, story_with_images.decorate)
    end

    it "constrains and centers the primary image so it does not render too large" do
      render
      expect(rendered).to include("max-w-2xl")
      expect(rendered).to include("mx-auto")
    end

    it "renders gallery images at the enlarged size" do
      render
      expect(rendered).to include("w-48")
      expect(rendered).to include("h-48")
    end
  end
end
