require 'rails_helper'

RSpec.describe "workshop_ideas/index", type: :view do
    let(:user) { create(:user) }
  let(:workshop_idea1) { create(:workshop_idea, created_by: user, updated_by: user, title: "MyStory1") }
  let(:workshop_idea2) { create(:workshop_idea, created_by: user, updated_by: user, title: "MyStory2") }

  before(:each) do
    assign(:workshop_ideas, paginated([workshop_idea1, workshop_idea2]))
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders a list of story_ideas" do
    render
    expect(rendered).to include(workshop_idea1.title, workshop_idea2.title)
  end

  it "renders a friendly message when no workshop_ideas exist" do
    assign(:workshop_ideas, paginated([]))
    render
    expect(rendered).to match(/No Workshop ideas found/)
  end
end
