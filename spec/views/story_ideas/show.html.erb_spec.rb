require "rails_helper"

RSpec.describe "story_ideas/show", type: :view do
  let(:user) { create(:user, :with_person) }

  before(:each) do
    assign(:story_idea, story_idea)
  end

  context "with a workshop" do
    let(:story_idea) { create(:story_idea, created_by: user, updated_by: user, rhino_body: "<p>MyBody</p>") }

    it "renders attributes" do
      render
      expect(rendered).to match(story_idea.organization.name)
      expect(rendered).to match(story_idea.workshop.name)
      expect(rendered).to match(/MyBody/)
      expect(rendered).to match(story_idea.author_credit)
    end
  end

  context "with only an external workshop title" do
    let(:story_idea) do
      create(:story_idea, created_by: user, updated_by: user,
             workshop: nil, external_workshop_title: "Community Art Session",
             rhino_body: "<p>MyBody</p>")
    end

    it "renders the external title" do
      render
      expect(rendered).to include("Community Art Session")
    end
  end

  context "with both workshop and external title" do
    let(:story_idea) do
      create(:story_idea, created_by: user, updated_by: user,
             external_workshop_title: "Community Art Session",
             rhino_body: "<p>MyBody</p>")
    end

    it "renders both titles" do
      render
      expect(rendered).to include(story_idea.workshop.title)
      expect(rendered).to include("Community Art Session")
    end
  end

  context "with no workshop or external title" do
    let(:story_idea) do
      create(:story_idea, created_by: user, updated_by: user,
             workshop: nil, external_workshop_title: nil,
             rhino_body: "<p>MyBody</p>")
    end

    it "renders a dash for workshop" do
      render
      expect(rendered).to include("Workshop:")
      expect(rendered).to match(/Workshop:.*—/m)
    end
  end
end
