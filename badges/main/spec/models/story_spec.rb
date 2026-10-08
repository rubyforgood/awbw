require 'rails_helper'

RSpec.describe Story, type: :model do
  it_behaves_like "author_creditable", factory: :story, org_credited: false

  describe "#missing_author_label" do
    it "credits unattributed stories to AWBW Facilitator" do
      story = create(:story, author: nil, created_by: create(:user, person: nil))
      expect(story.missing_author_label).to eq("AWBW Facilitator")
      expect(story.author_credit).to eq("AWBW Facilitator")
    end
  end

  describe "#author_person" do
    let(:creator) { create(:user, :with_person) }
    let(:facilitator) { create(:person) }

    it "returns the explicitly chosen author when present" do
      story = create(:story, created_by: creator, author: facilitator)
      expect(story.author_person).to eq(facilitator)
    end

    it "falls back to the creating user's person when no author is set" do
      story = create(:story, created_by: creator, author: nil)
      expect(story.author_person).to eq(creator.person)
    end

    it "credits the author over the creator via author_credit" do
      story = create(:story, created_by: creator, author: facilitator,
                             author_credit_preference: "full_name")
      expect(story.author_credit).to eq(facilitator.full_name)
    end
  end

  describe "a second author" do
    let(:first_author) { create(:person, first_name: "Ada", last_name: "Lovelace", display_name_preference: "full_name") }
    let(:second_author) { create(:person, first_name: "Grace", last_name: "Hopper", display_name_preference: "full_name") }

    def two_author_story(**attrs)
      create(:story, author: first_author, co_author: second_author,
                     author_credit_preference: "full_name", co_author_credit_preference: "full_name", **attrs)
    end

    describe "#author_credit" do
      it "joins both named authors" do
        expect(two_author_story.author_credit).to eq("Ada Lovelace and Grace Hopper")
      end

      it "appends each author's visible credentials" do
        create(:professional_license, person: first_author, kind: "LMFT")
        create(:professional_license, person: first_author, kind: "MSW")
        second_author.update!(display_name_preference: "first_name_last_initial")
        expect(two_author_story.author_credit).to eq("Ada Lovelace, LMFT, MSW and Grace H.")
      end

      it "omits credentials the author hides on their profile" do
        create(:professional_license, person: first_author, kind: "LMFT")
        first_author.update!(profile_show_credentials: false)
        expect(two_author_story.author_credit).to eq("Ada Lovelace and Grace Hopper")
      end

      it "drops the anonymous co-author and shows only the first author" do
        story = two_author_story(co_author_credit_preference: "anonymous")
        expect(story.author_credit).to eq("Ada Lovelace")
      end

      it "drops the anonymous first author and shows only the co-author" do
        story = two_author_story(author_credit_preference: "anonymous")
        expect(story.author_credit).to eq("Grace Hopper")
      end

      it "falls back to the generic label when both authors are anonymous" do
        story = two_author_story(author_credit_preference: "anonymous", co_author_credit_preference: "anonymous")
        expect(story.author_credit).to eq("AWBW Facilitator")
      end

      it "honors each author's own profile display preference" do
        second_author.update!(display_name_preference: "first_name_only")
        story = create(:story, author: first_author, co_author: second_author,
                               author_credit_preference: nil, co_author_credit_preference: nil)
        expect(story.author_credit).to eq("Ada Lovelace and Grace")
      end
    end

    describe "#credited_author_people" do
      it "returns both credited people in order" do
        expect(two_author_story.credited_author_people).to eq([ first_author, second_author ])
      end

      it "omits an anonymous co-author" do
        story = two_author_story(co_author_credit_preference: "anonymous")
        expect(story.credited_author_people).to eq([ first_author ])
      end
    end

    describe "#credit_anonymous_for?" do
      it "is true for the co-author when their credit is suppressed" do
        story = two_author_story(co_author_credit_preference: "anonymous")
        expect(story.credit_anonymous_for?(second_author)).to be(true)
        expect(story.credit_anonymous_for?(first_author)).to be(false)
      end
    end

    describe "validation" do
      it "rejects the same person as both authors" do
        story = build(:story, author: first_author, co_author: first_author)
        expect(story).not_to be_valid
        expect(story.errors[:co_author_id]).to be_present
      end

      # Every author_id-is-null fallback (the profile listing's creator credit, the
      # divergences page's creator and unattributed sections) would treat a story
      # with only a second author as having no author at all.
      it "rejects a second author with no first author" do
        story = build(:story, author: nil, co_author: second_author)
        expect(story).not_to be_valid
        expect(story.errors[:author_id]).to be_present
      end

      it "rejects an invalid co-author credit preference" do
        story = build(:story, author: first_author, co_author: second_author, co_author_credit_preference: "sideways")
        expect(story).not_to be_valid
        expect(story.errors[:co_author_credit_preference]).to be_present
      end
    end

    describe "the co-author consent snapshot" do
      it "records the co-author's profile preference on create" do
        second_author.update!(display_name_preference: "first_name_only")
        story = create(:story, author: first_author, co_author: second_author, co_author_credit_preference: nil)
        expect(story.reload.co_author_credit_preference).to eq("first_name_only")
      end
    end

    describe "search and filtering" do
      let!(:story) { two_author_story(title: "Two Authors") }

      it "finds the story by the co-author's name" do
        expect(Story.by_credited_person_name("Hopper")).to include(story)
      end

      # The credit renders "Grace H." — pasting that back into the search box has to
      # find it, so the period can't be a mismatch.
      it "finds the story by the initialled name as it displays" do
        second_author.update!(display_name_preference: "first_name_last_initial")
        expect(Story.by_credited_person_name("Grace H.")).to include(story)
      end

      it "matches nothing by the co-author name when they are anonymous" do
        story.update!(co_author_credit_preference: "anonymous")
        expect(Story.by_credited_person_name("Hopper")).not_to include(story)
      end

      it "filters to stories by either author via authored_by" do
        expect(Story.authored_by(second_author.id)).to include(story)
        expect(Story.authored_by(first_author.id)).to include(story)
      end

      it "lists the story under the co-author via credited_to_person" do
        expect(Story.credited_to_person(second_author)).to include(story)
      end
    end
  end

  describe "#attach_assets_from_idea!" do
    let(:idea) { create(:story_idea) }
    let(:story) { create(:story, story_idea: idea) }

    before do
      create(:gallery_asset, :with_file, owner: idea)
      create(:gallery_asset, :with_file, owner: idea)
      create(:gallery_asset, :with_file, owner: idea)
    end

    it "promotes the first gallery asset to primary" do
      story.attach_assets_from_idea!
      story.reload

      expect(story.primary_asset).to be_present
      expect(story.primary_asset.file).to be_attached
    end

    it "keeps remaining gallery assets as gallery" do
      story.attach_assets_from_idea!
      story.reload

      expect(story.gallery_assets.count).to eq(2)
      story.gallery_assets.each do |asset|
        expect(asset.file).to be_attached
      end
    end

    it "appends idea assets after existing gallery assets" do
      create(:gallery_asset, :with_file, owner: story)

      story.attach_assets_from_idea!

      expect(story.assets.count).to eq(4)
    end

    it "does nothing without a linked idea" do
      story_without_idea = create(:story, story_idea: nil)
      expect { story_without_idea.attach_assets_from_idea! }.not_to change { story_without_idea.assets.count }
    end

    context "when user uploaded a primary asset" do
      before { create(:primary_asset, :with_file, owner: story) }

      it "keeps the user-uploaded primary" do
        original_blob_id = story.primary_asset.file.blob_id

        story.attach_assets_from_idea!
        story.reload

        expect(story.primary_asset.file.blob_id).to eq(original_blob_id)
      end

      it "adds all idea assets as gallery" do
        story.attach_assets_from_idea!
        story.reload

        expect(story.gallery_assets.count).to eq(3)
      end

      it "does not create a second primary asset" do
        story.attach_assets_from_idea!
        story.reload

        expect(story.assets.where(type: "PrimaryAsset").count).to eq(1)
      end
    end

    context "when user uploaded gallery assets" do
      before { create(:gallery_asset, :with_file, owner: story) }

      it "keeps user-uploaded gallery assets" do
        original_blob_id = story.gallery_assets.first.file.blob_id

        story.attach_assets_from_idea!
        story.reload

        expect(story.gallery_assets.map(&:file).map(&:blob_id)).to include(original_blob_id)
      end

      it "promotes first idea gallery to primary when no primary exists" do
        story.attach_assets_from_idea!
        story.reload

        expect(story.primary_asset).to be_present
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

    it 'filters by organization_id' do
      organization = create(:organization)
      org_story = create(:story, organization: organization)

      results = Story.search_by_params(organization_id: organization.id)
      expect(results).to include(org_story)
      expect(results).not_to include(published_story, draft_story, old_story)
    end

    context 'when the query matches a credited person name' do
      let(:creator) { create(:user, person: create(:person, first_name: 'Zephyrina', last_name: 'Quackenbush')) }
      let(:facilitator) { create(:person, first_name: 'Bartholomew', last_name: 'Snazzlepants') }
      let!(:authored_story) { create(:story, :published, title: 'No Name Match', created_by: creator, author: facilitator) }

      it 'finds stories by the explicit author name' do
        results = Story.search_by_params(query: 'Bartholomew')
        expect(results).to include(authored_story)
        expect(results).not_to include(published_story)
      end

      it "does not find stories by the name of whoever entered them" do
        created_story = create(:story, :published, title: 'Creator Only', created_by: creator)
        results = Story.search_by_params(query: 'Zephyrina')
        expect(results).not_to include(created_story)
      end
    end

    context 'when filtering by the author_name field' do
      let(:facilitator) { create(:person, first_name: 'Bartholomew', last_name: 'Snazzlepants') }
      let!(:authored_story) { create(:story, :published, title: 'No Name Match', author: facilitator) }

      it 'filters to stories whose credited author name matches' do
        results = Story.search_by_params(author_name: 'Bartholomew')
        expect(results).to include(authored_story)
        expect(results).not_to include(published_story)
      end
    end
  end

  describe ".not_funder_only" do
    it "excludes funder-only stories and keeps the rest" do
      regular = create(:story)
      funder_only = create(:story, :funder_only)

      expect(Story.not_funder_only).to include(regular)
      expect(Story.not_funder_only).not_to include(funder_only)
    end
  end

  describe "#to_param" do
    it "is the id followed by the title slugged with hyphens, stripping bad URL characters" do
      story = create(:story, title: "My Great Story! #2 (2026)")
      expect(story.to_param).to eq("#{story.id}-my-great-story-2-2026")
    end

    it "tracks the title when it changes" do
      story = create(:story, title: "Original Title")
      story.update!(title: "Brand New Title")
      expect(story.to_param).to eq("#{story.id}-brand-new-title")
    end

    it "resolves back to the record via the leading id" do
      story = create(:story, title: "Some Story")
      expect(Story.find(story.to_param)).to eq(story)
    end
  end

  describe "#audience_categories" do
    it "returns only AgeRange and StoryPopulation categories" do
      story = create(:story)
      population = create(:category_type, name: "StoryPopulation")
      age_range = create(:category_type, name: "AgeRange")
      other_type = create(:category_type, name: "ArtType")
      self_category = create(:category, name: "Self", category_type: population)
      teens = create(:category, name: "Teens", category_type: age_range)
      clay = create(:category, name: "Clay", category_type: other_type)
      story.categorizable_items.create!(category: self_category)
      story.categorizable_items.create!(category: teens)
      story.categorizable_items.create!(category: clay)

      expect(story.audience_categories).to contain_exactly(self_category, teens)
    end
  end

  describe ".search_by_params keyword query" do
    it "matches on the title" do
      match = create(:story, title: "Watercolor journey")
      create(:story, title: "Something else")
      expect(Story.search_by_params(query: "Watercolor")).to contain_exactly(match)
    end
  end

  describe "linked workshops" do
    let(:story) { create(:story, workshop: nil) }
    let(:workshop) { create(:workshop) }

    it "rejects the same workshop submitted twice in one save" do
      story.assign_attributes(story_workshops_attributes: [ { workshop_id: workshop.id },
                                                           { workshop_id: workshop.id } ])

      expect(story).not_to be_valid
      expect(story.errors.full_messages.join).to include("is already linked to this story")
    end

    it "accepts the same workshop twice when the titles differ" do
      story.assign_attributes(story_workshops_attributes: [
        { workshop_id: workshop.id },
        { workshop_id: workshop.id, external_workshop_title: "Teen variant" }
      ])

      expect(story).to be_valid
      expect { story.save! }.not_to raise_error
      expect(story.reload.story_workshops.map(&:external_workshop_title)).to contain_exactly(nil, "Teen variant")
    end

    it "allows removing a row and re-adding the same workshop in one save" do
      existing = story.story_workshops.create!(workshop: workshop)
      story.assign_attributes(story_workshops_attributes: [
        { id: existing.id, _destroy: "1" },
        { workshop_id: workshop.id, external_workshop_title: "Retyped" }
      ])

      expect(story).to be_valid
      expect { story.save! }.not_to raise_error
      expect(story.reload.story_workshops.sole.external_workshop_title).to eq("Retyped")
    end

    it "rejects the same workshop submitted twice before the story is saved" do
      unsaved = Story.new(story_workshops_attributes: [ { workshop_id: workshop.id },
                                                        { workshop_id: workshop.id } ])

      expect(unsaved).not_to be_valid
      expect(unsaved.errors.full_messages.join).to include("is already linked to this story")
    end

    it "allows several rows with no workshop of their own" do
      story.assign_attributes(story_workshops_attributes: [ { external_workshop_title: "One" },
                                                           { external_workshop_title: "Two" } ])

      expect(story).to be_valid
    end
  end
end
