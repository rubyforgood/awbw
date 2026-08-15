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

  it "shows the created-by name through the person's display preference" do
    author = create(:user, :with_person)
    author.person.update!(first_name: "Rosalind", last_name: "Franklin",
                          display_name_preference: "first_name_last_initial")
    workshop_idea.update!(created_by: author, updated_by: author)
    render

    expect(rendered).to include("Rosalind F.")
    expect(rendered).not_to include("Rosalind Franklin")
  end
end
