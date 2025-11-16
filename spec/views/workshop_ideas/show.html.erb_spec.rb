require 'rails_helper'

RSpec.describe "workshop_ideas/show", type: :view do
    let(:user) { create(:user) }
  let(:workshop_idea) { create(:workshop_idea, created_by: user, updated_by: user,
                               title: "MyTitle", description: "MyDescription") }

  before(:each) do
    assign(:workshop_idea, workshop_idea)
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to include(/MyTitle/)
    expect(rendered).to include(/MyDescription/)
  end
end
