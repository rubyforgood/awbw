require "rails_helper"

RSpec.describe AuthorCreditDivergenceQuery do
  let(:author_user) { create(:user, :with_person) }
  let(:person) { author_user.person }

  # Snapshot "first_name_only", then move the profile so the two disagree.
  def diverged_story
    person.update!(display_name_preference: "first_name_only")
    story = create(:story, created_by: author_user, author: person, author_credit_preference: nil)
    person.update!(display_name_preference: "full_name")
    story
  end

  describe "#call" do
    it "returns nothing when every snapshot matches its profile" do
      person.update!(display_name_preference: "full_name")
      create(:story, created_by: author_user, author: person, author_credit_preference: nil)

      expect(described_class.new.call).to be_empty
    end

    it "groups diverging records under their credited person" do
      story = diverged_story

      groups = described_class.new.call

      expect(groups.size).to eq(1)
      expect(groups.first.person).to eq(person)
      expect(groups.first.records).to include(story)
    end

    it "finds records credited through the creating user's person, not just author_id" do
      person.update!(display_name_preference: "first_name_only")
      idea = create(:story_idea, created_by: author_user, author_credit_preference: nil)
      person.update!(display_name_preference: "full_name")

      expect(described_class.new.call.first.records).to include(idea)
    end

    it "ignores records with no stored snapshot" do
      create(:story, created_by: author_user, author: person, author_credit_preference: nil)
      Story.update_all(author_credit_preference: nil)

      expect(described_class.new.call).to be_empty
    end

    it "suggests the most restrictive preference across the person's records" do
      diverged_story
      create(:story, created_by: author_user, author: person, author_credit_preference: "anonymous")

      expect(described_class.new.call.first.suggested_preference).to eq("anonymous")
    end
  end

  describe "filters" do
    before { diverged_story }

    it "filters by person_id" do
      expect(described_class.new(person_id: person.id).call.size).to eq(1)
      expect(described_class.new(person_id: person.id + 9999).call).to be_empty
    end

    it "filters by type" do
      expect(described_class.new(type: "Story").call.size).to eq(1)
      expect(described_class.new(type: "Resource").call).to be_empty
    end

    it "filters by stored preference" do
      expect(described_class.new(preference: "first_name_only").call.size).to eq(1)
      expect(described_class.new(preference: "anonymous").call).to be_empty
    end

    it "hides reconciled people unless asked for" do
      person.update!(author_credit_reconciled_at: Time.current)

      expect(described_class.new.call).to be_empty
      expect(described_class.new(include_reconciled: "1").call.size).to eq(1)
    end
  end

  describe ".model_for" do
    it "resolves an allowlisted name" do
      expect(described_class.model_for("Story")).to eq(Story)
    end

    it "refuses anything else rather than constantizing it" do
      expect(described_class.model_for("User")).to be_nil
      expect(described_class.model_for("Kernel")).to be_nil
      expect(described_class.model_for("NotAClass")).to be_nil
    end
  end
end
