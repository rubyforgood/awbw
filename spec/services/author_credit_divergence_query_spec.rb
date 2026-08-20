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

      expect(described_class.new.call.preference).to be_empty
    end

    it "groups diverging records under their credited person" do
      story = diverged_story

      groups = described_class.new.call.preference

      expect(groups.size).to eq(1)
      expect(groups.first.person).to eq(person)
      expect(groups.first.records).to include(story)
    end

    it "never puts an idea in the preference section — it credits generically, so nothing to reconcile" do
      person.update!(display_name_preference: "first_name_only")
      idea = create(:story_idea, created_by: author_user, author_credit_preference: nil)
      person.update!(display_name_preference: "full_name")

      records = described_class.new.call.preference.flat_map(&:records)
      expect(records).not_to include(idea)
      expect(described_class.new(type: "StoryIdea").call.preference).to be_empty
    end

    it "ignores records with no stored snapshot" do
      create(:story, created_by: author_user, author: person, author_credit_preference: nil)
      Story.update_all(author_credit_preference: nil)

      expect(described_class.new.call.preference).to be_empty
    end

    it "orders groups by first name then last name" do
      person.update!(first_name: "Zoe", last_name: "Adams")
      diverged_story
      early_user = create(:user, :with_person)
      early_user.person.update!(first_name: "Ada", last_name: "Zimmerman")
      early_user.person.update!(display_name_preference: "first_name_only")
      create(:story, created_by: early_user, author: early_user.person, author_credit_preference: nil)
      early_user.person.update!(display_name_preference: "full_name")

      names = described_class.new.call.preference.map { |group| group.person.first_name }

      expect(names).to eq(%w[Ada Zoe])
    end

    it "suggests the most restrictive preference across the person's records" do
      diverged_story
      create(:story, created_by: author_user, author: person, author_credit_preference: "anonymous")

      expect(described_class.new.call.preference.first.suggested_preference).to eq("anonymous")
    end
  end

  describe "filters" do
    before { diverged_story }

    it "filters by person_id" do
      expect(described_class.new(person_id: person.id).call.preference.size).to eq(1)
      expect(described_class.new(person_id: person.id + 9999).call.preference).to be_empty
    end

    it "filters by type" do
      expect(described_class.new(type: "Story").call.preference.size).to eq(1)
      expect(described_class.new(type: "Resource").call.preference).to be_empty
    end

    it "filters by stored preference" do
      expect(described_class.new(preference: "first_name_only").call.preference.size).to eq(1)
      expect(described_class.new(preference: "anonymous").call.preference).to be_empty
    end

    it "hides reconciled people unless asked for" do
      person.update!(author_credit_reconciled_at: Time.current)

      expect(described_class.new.call.preference).to be_empty
      expect(described_class.new(include_reconciled: "1").call.preference.size).to eq(1)
    end
  end

  describe "the legacy section" do
    def legacy_records_for(column)
      group = described_class.new.call.legacy.find { |g| g.column == column }
      group.entries.map(&:record)
    end

    it "lists records credited by a free-text name with no person" do
      workshop = create(:workshop, author: nil, full_name: "Marguerite Pre-Person")

      expect(legacy_records_for("workshops.full_name")).to include(workshop)
      expect(workshop.author_credit).to eq("Marguerite Pre-Person")
    end

    it "drops a record once a real author is credited" do
      workshop = create(:workshop, author: nil, full_name: "Marguerite Pre-Person")
      workshop.update!(author: person)

      expect(legacy_records_for("workshops.full_name")).not_to include(workshop)
    end

    it "keeps a group per legacy column even when it is empty, so each can be retired" do
      columns = described_class.new.call.legacy.map(&:column)

      expect(columns).to contain_exactly("workshops.full_name", "resources.legacy_author_name")
      expect(described_class.new.call).to be_legacy_empty
    end

    it "excludes models that have no legacy column" do
      create(:story, created_by: author_user, author: nil)
      expect(described_class.new.call.legacy.flat_map(&:entries)).to be_empty
    end

    it "suggests a person whose name matches the legacy text" do
      match = create(:person, first_name: "Marguerite", last_name: "Duras")
      workshop = create(:workshop, author: nil, full_name: "Marguerite Duras")

      entry = described_class.new.call.legacy
                             .find { |g| g.column == "workshops.full_name" }
                             .entries.find { |e| e.record == workshop }

      expect(entry.suggested_author).to eq(match)
    end

    it "suggests nothing when no person matches" do
      workshop = create(:workshop, author: nil, full_name: "Nobody Byanyname")

      entry = described_class.new.call.legacy
                             .find { |g| g.column == "workshops.full_name" }
                             .entries.find { |e| e.record == workshop }

      expect(entry.suggested_author).to be_nil
    end
  end

  describe "the creator section" do
    it "groups records whose author_id is blank under the creating person" do
      story = create(:story, created_by: author_user, author: nil)

      groups = described_class.new.call.creator

      expect(groups.map(&:person)).to include(person)
      expect(groups.find { |g| g.person == person }.records).to include(story)
    end

    it "excludes records that already name an author" do
      story = create(:story, created_by: author_user, author: person)
      expect(described_class.new.call.creator.flat_map(&:records)).not_to include(story)
    end

    it "excludes idea models, whose only credit path is the creator" do
      idea = create(:story_idea, created_by: author_user)
      expect(described_class.new.call.creator.flat_map(&:records)).not_to include(idea)
    end

    it "excludes records covered by the legacy section instead" do
      workshop = create(:workshop, created_by: author_user, author: nil, full_name: "Legacy Name")
      expect(described_class.new.call.creator.flat_map(&:records)).not_to include(workshop)
    end
  end

  describe "the unattributed section" do
    let(:personless_user) { create(:user, person: nil) }

    it "lists records with no author, no legacy name, and no creator person" do
      story = create(:story, created_by: personless_user, author: nil)

      expect(described_class.new.call.unattributed).to include(story)
      expect(story.author_credit).to eq(story.missing_author_label)
    end

    it "drops a record once an author is credited" do
      story = create(:story, created_by: personless_user, author: nil)
      story.update!(author: person)

      expect(described_class.new.call.unattributed).not_to include(story)
    end
  end

  describe "#empty?" do
    it "is true only when every section is clear" do
      expect(described_class.new.call).to be_empty

      create(:story, created_by: create(:user, person: nil), author: nil)
      expect(described_class.new.call).not_to be_empty
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
