require 'rails_helper'

RSpec.describe Story, type: :model do
  describe "#author_credit" do
    let(:user) { create(:user, :with_person) }
    let(:person) { user.person }
    let(:story) { create(:story, created_by: user) }

    context "when author_credit_preference is full name" do
      it "returns the person's full name" do
        story.update!(author_credit_preference: "full_name")
        expect(story.author_credit).to eq(person.full_name)
      end
    end

    context "when author_credit_preference is first name only" do
      it "returns the person's first name" do
        story.update!(author_credit_preference: "first_name_only")
        expect(story.author_credit).to eq(person.first_name)
      end
    end

    context "when author_credit_preference is anonymous" do
      it "returns Anonymous" do
        story.update!(author_credit_preference: "anonymous")
        expect(story.author_credit).to eq("Anonymous")
      end
    end

    context "when author_credit_preference is nil" do
      it "falls back to the person's display name preference" do
        expect(story.author_credit_preference).to be_nil
        expect(story.author_credit).to eq(person.name)
      end
    end

    context "when user has no person" do
      let(:user) { create(:user, person: nil) }

      it "returns Anonymous" do
        expect(story.author_credit).to eq("Anonymous")
      end
    end
  end

  describe '.search_by_params' do
    let!(:published_story) { create(:story, :published, title: 'Healing Through Art') }
    let!(:draft_story) { create(:story, title: 'Unpublished Draft', published: false) }
    let!(:old_story) do
      create(:story, :published, title: 'Last Year Story').tap do |s|
        s.update_columns(created_at: Date.new(2025, 5, 1))
      end
    end

    it 'returns all when no params' do
      results = Story.search_by_params({})
      expect(results).to include(published_story, draft_story, old_story)
    end

    it 'filters by title' do
      results = Story.search_by_params(title: 'Healing')
      expect(results).to include(published_story)
      expect(results).not_to include(draft_story)
    end

    it 'filters by published param' do
      results = Story.search_by_params(published: 'true')
      expect(results).to include(published_story, old_story)
      expect(results).not_to include(draft_story)
    end

    it 'filters by year' do
      results = Story.search_by_params(year: '2025')
      expect(results).to include(old_story)
      expect(results).not_to include(published_story)
    end

    it 'chains title and published filters' do
      results = Story.search_by_params(title: 'Healing', published: 'true')
      expect(results).to include(published_story)
      expect(results).not_to include(draft_story, old_story)
    end
  end
end
