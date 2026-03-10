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
          "Resource", "Story", "StoryIdea", "VideoRecording", "Workshop",
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
      video_recording_option = options.find { |_, value| value == "VideoRecording" }
      expect(video_recording_option.first).to eq(VideoRecording.model_name.human)
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

    it 'applies keyword correctly' do
      params = { keyword: "Alpha" }
      result = Bookmark.filter_by_params(params)
      expect(result).to include(bookmark1)
      expect(result).not_to include(bookmark2)
    end

    it 'returns all bookmarks if no params are provided' do
      result = Bookmark.filter_by_params({})
      expect(result).to include(bookmark1, bookmark2)
    end
  end

  describe "video_recording bookmarks" do
    let(:user) { create(:user) }
    let!(:video_recording) { create(:video_recording, :published, title: "Getting Started") }
    let!(:video_recording_bookmark) { create(:bookmark, user: user, bookmarkable: video_recording) }

    it "filters by keyword matching video_recording" do
      result = Bookmark.filter_by_params(keyword: "Getting")
      expect(result).to include(video_recording_bookmark)
    end

    it "excludes non-matching video_recordings in keyword filter" do
      result = Bookmark.filter_by_params(keyword: "Nonexistent")
      expect(result).not_to include(video_recording_bookmark)
    end

    it "includes video_recording bookmarks when sorting by title" do
      result = Bookmark.sorted("title")
      expect(result).to include(video_recording_bookmark)
    end
  end

  describe ".filter_by_params with keyword and windows_type combined" do
    let(:user) { create(:user) }
    let!(:windows_type) { create(:windows_type, name: "COMBINED") }
    let!(:resource) { create(:resource, title: "Test Resource", windows_type: windows_type) }
    let!(:bookmark) { create(:bookmark, user: user, bookmarkable: resource) }

    it "does not raise a duplicate table alias error" do
      params = { keyword: "Test", windows_type: "Combined" }
      expect { Bookmark.filter_by_params(params) }.not_to raise_error
    end

    it "returns matching bookmarks" do
      params = { keyword: "Test", windows_type: "Combined" }
      result = Bookmark.filter_by_params(params)
      expect(result).to include(bookmark)
    end

    it "works when also sorting by title" do
      params = { keyword: "Test", windows_type: "Combined" }
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

    it "returns all bookmarks by default" do
      result = Bookmark.search({})
      expect(result.count).to eq(14)
    end

    context "with keyword filter and title sort combined" do
      it "does not produce duplicate table joins" do
        expect {
          Bookmark.search({ keyword: "Alpha" }).sorted("title").to_a
        }.not_to raise_error
      end

      it "filters and sorts correctly" do
        result = Bookmark.search({ keyword: "Alpha" }).sorted("title")
        expect(result.map(&:bookmarkable).uniq).to eq([ workshop1 ])
      end
    end

    context "with keyword filter and newest sort" do
      it "filters by keyword and sorts by newest" do
        result = Bookmark.search({ keyword: "Bravo" }).sorted("created_at")
        expect(result.map(&:bookmarkable).uniq).to eq([ workshop2 ])
      end
    end

    context "with keyword filter and popularity sort" do
      it "does not raise" do
        expect {
          Bookmark.search({ keyword: "Alpha" }).sorted("popularity").to_a
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
          Bookmark.search({}, user: user).sorted("title").to_a
        }.not_to raise_error
      end

      it "does not produce duplicate joins with keyword filter and title sort" do
        expect {
          Bookmark.search({ keyword: "Alpha" }, user: user).sorted("title").to_a
        }.not_to raise_error
      end
    end
  end

  describe ".keyword" do
    let(:user) { create(:user) }

    context "with ActionText body content" do
      let!(:news) { create(:community_news, title: "Newsletter", rhino_body: "This discusses healing through art therapy") }
      let!(:news_bookmark) { create(:bookmark, user: user, bookmarkable: news) }
      let!(:other_news) { create(:community_news, title: "Update") }
      let!(:other_bookmark) { create(:bookmark, user: user, bookmarkable: other_news) }

      it "matches ActionText body content" do
        # Ensure ActionText record is persisted and queryable
        expect(news.rhino_body.body.to_plain_text).to include("healing")
        result = Bookmark.keyword("healing")
        expect(result).to include(news_bookmark)
        expect(result).not_to include(other_bookmark)
      end

      it "matches title as well as body" do
        result = Bookmark.keyword("Newsletter")
        expect(result).to include(news_bookmark)
      end
    end
  end

  describe ".sorted" do
    let(:user) { create(:user) }
    let!(:workshop1) { create(:workshop, title: "Zebra") }
    let!(:workshop2) { create(:workshop, title: "Apple") }
    let!(:bookmark1) { create(:bookmark, user: user, bookmarkable: workshop1, created_at: 2.days.ago) }
    let!(:bookmark2) { create(:bookmark, user: user, bookmarkable: workshop2, created_at: 1.day.ago) }

    it "defaults to newest (desc)" do
      result = Bookmark.sorted
      expect(result.first).to eq(bookmark2)
    end

    it "sorts by title asc" do
      result = Bookmark.sorted("title", "asc")
      expect(result.first.bookmarkable).to eq(workshop2) # Apple before Zebra
    end

    it "sorts by title desc" do
      result = Bookmark.sorted("title", "desc")
      expect(result.first.bookmarkable).to eq(workshop1) # Zebra before Apple
    end

    it "sorts by created_at asc" do
      result = Bookmark.sorted("created_at", "asc")
      expect(result.first).to eq(bookmark1)
    end
  end
end
