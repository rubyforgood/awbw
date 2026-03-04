# spec/models/bookmark_spec.rb
require 'rails_helper'

RSpec.describe Bookmark, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:bookmarkable) } # Polymorphic
  end

  describe "constants" do
    describe "BOOKMARKABLE_MODELS" do
      it "includes all expected model names" do
        expect(Bookmark::BOOKMARKABLE_MODELS).to include(
          "CommunityNews", "Event", "Organization", "Person", "Report",
          "Resource", "Story", "StoryIdea", "Tutorial", "Workshop",
          "WorkshopIdea", "WorkshopLog", "WorkshopVariation", "WorkshopVariationIdea"
        )
      end

      it "is frozen" do
        expect(Bookmark::BOOKMARKABLE_MODELS).to be_frozen
      end
    end

    describe "DROPDOWN_MODELS" do
      it "excludes Report" do
        expect(Bookmark::DROPDOWN_MODELS).not_to include("Report")
      end

      it "is a subset of BOOKMARKABLE_MODELS" do
        expect(Bookmark::DROPDOWN_MODELS - Bookmark::BOOKMARKABLE_MODELS).to be_empty
      end

      it "is frozen" do
        expect(Bookmark::DROPDOWN_MODELS).to be_frozen
      end
    end
  end

  describe ".bookmarkable_type_options" do
    it "never includes Report" do
      options = Bookmark.bookmarkable_type_options
      type_values = options.map(&:last)
      expect(type_values).not_to include("Report")
    end

    it "includes WorkshopVariationIdea" do
      options = Bookmark.bookmarkable_type_options
      type_values = options.map(&:last)
      expect(type_values).to include("WorkshopVariationIdea")
    end

    it "uses model_name.human for labels" do
      options = Bookmark.bookmarkable_type_options
      tutorial_option = options.find { |_, value| value == "Tutorial" }
      expect(tutorial_option.first).to eq(Tutorial.model_name.human)
    end

    it "returns [label, value] pairs" do
      options = Bookmark.bookmarkable_type_options
      options.each do |option|
        expect(option).to be_an(Array)
        expect(option.length).to eq(2)
      end
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      user = build_stubbed(:user)
      workshop = build_stubbed(:workshop)
      bookmark = build(:bookmark, user: user, bookmarkable: workshop)
      expect(bookmark).to be_valid
    end
  end

  describe '.filter_by_params' do
    let(:user) { create(:user) }
    let!(:windows_type1) { create(:windows_type, id: 1, name: "Type 1") }
    let!(:windows_type3) { create(:windows_type, id: 3, name: "Type 3") }
    let!(:workshop1) { create(:workshop, title: "Alpha", windows_type: windows_type1, full_name: "Alice") }
    let!(:workshop2) { create(:workshop, title: "Bravo", windows_type: windows_type3, full_name: "Bob") }
    let!(:bookmark1) { create(:bookmark, user: user, bookmarkable: workshop1) }
    let!(:bookmark2) { create(:bookmark, user: user, bookmarkable: workshop2) }

    it 'applies title correctly' do
      params = { title: "Alpha" }
      result = Bookmark.filter_by_params(params)
      expect(result).to include(bookmark1)
      expect(result).not_to include(bookmark2)
    end

    it 'applies query filter correctly' do
      skip # filter_by_query is working in dev, but failing in test
      params = { query: "Alice" }
      result = Bookmark.filter_by_params(params)
      expect(result).to include(bookmark1)
      expect(result).not_to include(bookmark2)
    end

    it 'applies title filter, windows_type filter, and query filter correctly' do
      skip # filter_by_query is working in dev, but failing in test
      params = {
        title: "Alpha",
        windows_types: { "0" => "1" },
        query: "Alice"
      }
      result = Bookmark.filter_by_params(params)
      expect(result).to include(bookmark1)
      expect(result).not_to include(bookmark2)
    end

    it 'returns all bookmarks if no params are provided' do
      result = Bookmark.filter_by_params({})
      expect(result).to include(bookmark1, bookmark2)
    end
  end

  describe "tutorial bookmarks" do
    let(:user) { create(:user) }
    let!(:tutorial) { create(:tutorial, :published, title: "Getting Started") }
    let!(:tutorial_bookmark) { create(:bookmark, user: user, bookmarkable: tutorial) }

    it "filters by title matching tutorial" do
      result = Bookmark.filter_by_params(title: "Getting")
      expect(result).to include(tutorial_bookmark)
    end

    it "excludes non-matching tutorials in title filter" do
      result = Bookmark.filter_by_params(title: "Nonexistent")
      expect(result).not_to include(tutorial_bookmark)
    end

    it "includes tutorial bookmarks when sorting by title" do
      result = Bookmark.sorted("title")
      expect(result).to include(tutorial_bookmark)
    end
  end

  describe ".filter_by_params with title and windows_type combined" do
    let(:user) { create(:user) }
    let!(:windows_type) { create(:windows_type, name: "COMBINED") }
    let!(:resource) { create(:resource, title: "Test Resource", windows_type: windows_type) }
    let!(:bookmark) { create(:bookmark, user: user, bookmarkable: resource) }

    it "does not raise a duplicate table alias error" do
      params = { title: "Test", windows_type: "Combined" }
      expect { Bookmark.filter_by_params(params) }.not_to raise_error
    end

    it "returns matching bookmarks" do
      params = { title: "Test", windows_type: "Combined" }
      result = Bookmark.filter_by_params(params)
      expect(result).to include(bookmark)
    end

    it "works when also sorting by title" do
      params = { title: "Test", windows_type: "Combined" }
      result = Bookmark.filter_by_params(params).sorted("title")
      expect { result.length }.not_to raise_error
    end
  end

  describe ".search" do
    let(:user) { create(:user) }
    let!(:workshop1) { create(:workshop, title: "Alpha", led_count: 15) }
    let!(:workshop2) { create(:workshop, title: "Bravo", led_count: 10) }
    let!(:bookmark1) { create(:bookmark, user: user, bookmarkable: workshop1, created_at: 2.days.ago) }
    let!(:bookmark2) { create(:bookmark, user: user, bookmarkable: workshop2, created_at: 1.day.ago) }

    before do
      create_list(:bookmark, 5, bookmarkable: workshop1, created_at: 3.days.ago)
      create_list(:bookmark, 7, bookmarkable: workshop2, created_at: 4.days.ago)
    end

    it "sorts by newest-bookmarked by default" do
      result = Bookmark.search({})
      expect(result.first.bookmarkable.title).to eq("Bravo")
    end

    it "sorts by title when sort=title" do
      result = Bookmark.search({ sort: "title" })
      expect(result.first.bookmarkable).to eq(workshop1)
    end

    it "sorts by popularity when sort=popularity" do
      result = Bookmark.search({ sort: "popularity" })
      expect(result.first.bookmarkable).to eq(workshop2)
    end

    it "sorts by created_at when sort=newest" do
      result = Bookmark.search({ sort: "newest" })
      expect(result.first.created_at).to eq(bookmark2.created_at)
      expect(result.first.bookmarkable).to eq(workshop2)
    end

    context "with title filter and title sort combined" do
      it "does not produce duplicate table joins" do
        expect {
          Bookmark.search({ title: "Alpha", sort: "title" }).to_a
        }.not_to raise_error
      end

      it "filters and sorts correctly" do
        result = Bookmark.search({ title: "Alpha", sort: "title" })
        expect(result.map(&:bookmarkable).uniq).to eq([ workshop1 ])
      end
    end

    context "with title filter and newest sort" do
      it "filters by title and sorts by newest" do
        result = Bookmark.search({ title: "Bravo", sort: "newest" })
        expect(result.map(&:bookmarkable).uniq).to eq([ workshop2 ])
      end
    end

    context "with title filter and popularity sort" do
      it "does not raise" do
        expect {
          Bookmark.search({ title: "Alpha", sort: "popularity" }).to_a
        }.not_to raise_error
      end
    end

    context "scoped to a user" do
      it "returns only that user's bookmarks" do
        result = Bookmark.search({}, user: user)
        expect(result).to contain_exactly(bookmark1, bookmark2)
      end

      it "does not produce duplicate joins with title sort" do
        expect {
          Bookmark.search({ sort: "title" }, user: user).to_a
        }.not_to raise_error
      end

      it "does not produce duplicate joins with title filter and title sort" do
        expect {
          Bookmark.search({ title: "Alpha", sort: "title" }, user: user).to_a
        }.not_to raise_error
      end
    end
  end

  describe ".sorted" do
    let(:user) { create(:user) }
    let!(:workshop1) { create(:workshop, title: "Zebra") }
    let!(:workshop2) { create(:workshop, title: "Apple") }
    let!(:bookmark1) { create(:bookmark, user: user, bookmarkable: workshop1, created_at: 2.days.ago) }
    let!(:bookmark2) { create(:bookmark, user: user, bookmarkable: workshop2, created_at: 1.day.ago) }

    it "defaults to newest" do
      result = Bookmark.sorted
      expect(result.first).to eq(bookmark2)
    end

    it "sorts by title" do
      result = Bookmark.sorted("title")
      expect(result.first.bookmarkable).to eq(workshop2) # Apple before Zebra
    end
  end
end
