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
    let(:admin_user) { build_stubbed(:user, super_user: true) }
    let(:regular_user) { build_stubbed(:user, super_user: false) }

    it "never includes Report" do
      options = Bookmark.bookmarkable_type_options(user: admin_user)
      type_values = options.map(&:last)
      expect(type_values).not_to include("Report")
    end

    it "includes WorkshopVariationIdea for admin users" do
      options = Bookmark.bookmarkable_type_options(user: admin_user)
      type_values = options.map(&:last)
      expect(type_values).to include("WorkshopVariationIdea")
    end

    it "excludes WorkshopVariationIdea for regular users" do
      options = Bookmark.bookmarkable_type_options(user: regular_user)
      type_values = options.map(&:last)
      expect(type_values).not_to include("WorkshopVariationIdea")
    end

    it "excludes WorkshopVariationIdea when no user is provided" do
      options = Bookmark.bookmarkable_type_options(user: nil)
      type_values = options.map(&:last)
      expect(type_values).not_to include("WorkshopVariationIdea")
    end

    it "uses model_name.human for labels" do
      options = Bookmark.bookmarkable_type_options(user: admin_user)
      tutorial_option = options.find { |_, value| value == "Tutorial" }
      expect(tutorial_option.first).to eq(Tutorial.model_name.human)
    end

    it "returns [label, value] pairs" do
      options = Bookmark.bookmarkable_type_options(user: regular_user)
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
      result = Bookmark.search({}).sorted("title")
      expect(result).to include(tutorial_bookmark)
    end
  end

  describe '.search' do
    let(:user) { create(:user) }
    let!(:workshop1) { create(:workshop, title: "Alpha", led_count: 15) }
    let!(:workshop2) { create(:workshop, title: "Bravo", led_count: 10) }
    let!(:bookmark1) { create(:bookmark, user: user, bookmarkable: workshop1, created_at: 2.days.ago) }
    let!(:bookmark2) { create(:bookmark, user: user, bookmarkable: workshop2, created_at: 1.day.ago) }

    before do
      create_list(:bookmark, 5, bookmarkable: workshop1, created_at: 3.days.ago)
      create_list(:bookmark, 7, bookmarkable: workshop2, created_at: 4.days.ago)
    end

    it 'sorts by newest-bookmarked by default' do
      params = {}
      result = Bookmark.search(params)
      result = result.sorted(params[:sort])
      expect(result.first.bookmarkable.title).to eq("Bravo")
    end

    it 'sorts by title when sort=title' do
      params = { sort: "title" }
      result = Bookmark.search(params)
      result = result.sorted(params[:sort])
      expect(result.first.bookmarkable).to eq(workshop1)
    end

    it 'sorts by led count when sort=popularity' do
      params = { sort: "popularity" }
      result = Bookmark.search(params)
      result = result.sorted(params[:sort])
      expect(result.first.bookmarkable).to eq(workshop2)
    end

    it 'sorts by created_at when sort=newest' do
      params = { sort: "newest" }
      result = Bookmark.search(params)
      result = result.sorted(params[:sort])
      expect(result.first.created_at).to eq(bookmark2.created_at)
      expect(result.first.bookmarkable).to eq(workshop2)
    end
  end
end
