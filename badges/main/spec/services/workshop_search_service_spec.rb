# spec/services/workshop_search_service_spec.rb
require 'rails_helper'

RSpec.describe WorkshopSearchService, type: :service do
  let!(:workshop_1) do
    create(:workshop, :published, title: "A Workshop", year: 2025, month: 1, created_at: 5.days.ago, led_count: 5)
  end
  let!(:workshop_2) do
    create(:workshop, :published, title: "B Workshop", year: 2025, month: 2, created_at: 3.days.ago, led_count: 2)
  end
  let!(:workshop_3) do
    create(:workshop, :published, title: "Keyword Match", year: 2025, month: 1, created_at: 2.days.ago, led_count: 1)
  end
  let!(:publicly_visible_workshop) do
    create(:workshop, :published, title: "Public Workshop", publicly_visible: true, year: 2024, month: 11, created_at: 2.days.ago)
  end
  let!(:unpublished_workshop) do
    create(:workshop, title: "Hidden Draft", published: false, year: 2024, month: 12, created_at: 2.days.ago)
  end

  let!(:bookmark_1) { create(:bookmark, bookmarkable: workshop_1) }
  let!(:bookmark_2) { create(:bookmark, bookmarkable: workshop_1) }
  let!(:bookmark_3) { create(:bookmark, bookmarkable: workshop_2) }

  let!(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe "#call" do
    context "sorting by created" do
      it "orders by year/month desc, then created_at desc, then title asc" do
        service = WorkshopSearchService.new({ sort: 'created' }, user: user).call
        workshops = service.workshops

        # Assert order by attributes instead of object equality
        expect(workshops.map { |w| [ w.year, w.month, w.created_at.to_date, w.title ] }).to eq([
                                                                                               [ 2025, 2, 3.days.ago.to_date, "B Workshop" ],       # newest month first
                                                                                               [ 2025, 1, 2.days.ago.to_date, "Keyword Match" ],    # same month, newer created_at first
                                                                                               [ 2025, 1, 5.days.ago.to_date, "A Workshop" ],
                                                                                               [ 2024, 11, 2.days.ago.to_date, "Public Workshop" ]  # oldest
                                                                                             ])
      end
    end

    context "sorting by title" do
      it "orders alphabetically by title" do
        service = WorkshopSearchService.new({ sort: 'title' }, user: user).call
        workshops = service.workshops
        expect(workshops.map(&:title)).to eq([ "A Workshop", "B Workshop", "Keyword Match", "Public Workshop" ])
      end
    end

    context "sorting by led" do
      it "orders descending by led_count then title" do
        service = WorkshopSearchService.new({ sort: 'led' }, user: user).call
        workshops = service.workshops

        expect(workshops.map { |w| [ w.led_count, w.title ] }).to eq([
                                                                     [ 5, "A Workshop" ],
                                                                     [ 2, "B Workshop" ],
                                                                     [ 1, "Keyword Match" ],
                                                                     [ 0, "Public Workshop" ]
                                                                   ])
      end
    end

    context "sorting by bookmarks (popularity)" do
      it "orders by bookmarks_count desc, then title asc" do
        service = WorkshopSearchService.new({ sort: 'bookmarks' }, user: user).call
        workshops = service.workshops

        expect(workshops.map { |w| [ w.bookmarks_count.to_i, w.title ] }).to eq([
                                                                                [ 2, "A Workshop" ],
                                                                                [ 1, "B Workshop" ],
                                                                                [ 0, "Keyword Match" ],
                                                                                [ 0, "Public Workshop" ]
                                                                              ])
      end
    end

    # context "sorting by keywords" do # turned sorting by keywords off
    # 	it "returns workshops matching the query" do
    # 		# Stub filter_by_query to return a deterministic set
    # 		# This avoids relying on full-text search behavior in tests, which is unavailable
    # 		allow_any_instance_of(WorkshopSearchService)
    # 			.to receive(:filter_by_query) do |instance|
    # 			instance.instance_variable_set(:@workshops, [workshop_3])
    # 		end
    #
    # 		service = WorkshopSearchService.new({query: 'Keyword'}).call
    # 		workshops = service.workshops
    #
    # 		# Check inclusion or first element
    # 		expect(workshops).to include(workshop_3)
    # 		expect(workshops.first).to eq(workshop_3)
    # 	end
    # end

    context "as an admin" do
      it "includes unpublished workshops" do
        service = WorkshopSearchService.new({ sort: "title" }, user: admin).call
        expect(service.workshops.map(&:title)).to include("Hidden Draft")
        expect(service.workshops.map(&:title)).to include("Public Workshop")
        expect(service.workshops.map(&:title)).to include("A Workshop")
        expect(service.workshops.map(&:title)).to include("B Workshop")
        expect(service.workshops.map(&:title)).to include("Keyword Match")
      end
    end

    context "as a guest" do
      let(:user) { nil }

      it "shows only publicly_visible workshops" do
        service = WorkshopSearchService.new({ sort: "title" }, user: nil).call
        expect(service.workshops.map(&:title)).to include("Public Workshop")
        expect(service.workshops.map(&:title)).not_to include("Hidden Draft")
        expect(service.workshops.map(&:title)).not_to include("A Workshop")
        expect(service.workshops.map(&:title)).not_to include("B Workshop")
        expect(service.workshops.map(&:title)).not_to include("Keyword Match")
      end
    end

    context "default sort" do
      xit "defaults to keywords if query is present" do # only if using keyword sort
        service = WorkshopSearchService.new({ query: 'Keyword' }, user: user).call
        expect(service.sort).to eq('keywords')
      end

      it "defaults to created if no query or sort is provided" do
        service = WorkshopSearchService.new({}, user: user).call
        expect(service.sort).to eq('created')
      end
    end
  end
end
