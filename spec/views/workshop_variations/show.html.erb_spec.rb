require 'rails_helper'

RSpec.describe "workshop_variations/show", type: :view do
  let(:user) { create(:user) }
  let(:workshop) { create(:workshop, user: user) }
  let(:inactive) { false }
  let(:youtube_url) { nil }
  let(:workshop_variation) { create(:workshop_variation,
                                    workshop: workshop,
                                    created_by: user,
                                    name: "MyName", code: "MyDescription",
                                    youtube_url: youtube_url,
                                    inactive: inactive) }

  before(:each) do
    assign(:workshop_variation, workshop_variation)
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders attributes" do
    render
    expect(rendered).to include(workshop_variation.name)
    expect(rendered).to include(workshop_variation.code)
    expect(rendered).to include(workshop.title)
    expect(rendered).to include(user.name)
  end

  context 'when the workshop_variation has a youtube_url' do
    let(:youtube_url) { 'http://www.example.com/watch?v=somevideo' }

    it 'does renders the youtube_url as a link' do
      render
      expect(rendered).to have_link(youtube_url, href: youtube_url)
    end
  end

  context 'when the workshop_variation is inactive' do
    let(:inactive) { true }

    it 'displays a hidden indicator' do
      render
      expect(rendered).to include('[HIDDEN]')
    end
  end
end
