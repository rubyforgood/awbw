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

    context "punctuation-ignoring search" do
      let!(:workshop_with_hyphen) do
        create(:workshop, :published, title: "Hello - Goodbye", year: 2025, month: 3)
      end
      let!(:workshop_without_hyphen) do
        create(:workshop, :published, title: "Hello Goodbye", year: 2025, month: 4)
      end
      let!(:workshop_with_ampersand) do
        create(:workshop, :published, title: "Arts & Crafts", year: 2025, month: 5)
      end
      let!(:workshop_with_period) do
        create(:workshop, :published, title: "Dr. Workshop", year: 2025, month: 6)
      end
      let!(:workshop_with_em_dash) do
        create(:workshop, :published, title: "Hello—Goodbye", year: 2025, month: 7)
      end
      let!(:workshop_with_en_dash) do
        create(:workshop, :published, title: "Hello–Goodbye", year: 2025, month: 8)
      end
      let!(:workshop_with_quotes) do
        create(:workshop, :published, title: "The 'Best' Workshop", year: 2025, month: 9)
      end

      context "title search" do
        it "finds workshops with hyphens when searching without hyphens" do
          service = WorkshopSearchService.new({ title: 'Hello Goodbye' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_with_hyphen)
          expect(workshops).to include(workshop_without_hyphen)
        end

        it "finds workshops without hyphens when searching with hyphens" do
          service = WorkshopSearchService.new({ title: 'Hello - Goodbye' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_with_hyphen)
          expect(workshops).to include(workshop_without_hyphen)
        end

        it "finds workshops with multiple hyphens when searching with different hyphen patterns" do
          workshop_multi_hyphen = create(:workshop, :published, title: "Hello -- Goodbye", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'Hello Goodbye' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_multi_hyphen)
        end

        it "finds workshops with ampersands when searching without ampersands" do
          service = WorkshopSearchService.new({ title: 'Arts Crafts' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_with_ampersand)
        end

        it "finds workshops with periods when searching without periods" do
          service = WorkshopSearchService.new({ title: 'Dr Workshop' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_with_period)
        end

        it "finds workshops with em dashes when searching without them" do
          service = WorkshopSearchService.new({ title: 'HelloGoodbye' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_with_em_dash)
        end

        it "finds workshops with en dashes when searching without them" do
          service = WorkshopSearchService.new({ title: 'HelloGoodbye' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_with_en_dash)
        end

        it "finds workshops with quotes when searching without quotes" do
          service = WorkshopSearchService.new({ title: 'The Best Workshop' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_with_quotes)
        end

        it "finds workshops with slashes when searching without slashes" do
          workshop = create(:workshop, :published, title: "Art/Music", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'Art Music' }, user: user).call
          expect(service.workshops).to include(workshop)
        end

        it "finds workshops with colons when searching without colons" do
          workshop = create(:workshop, :published, title: "Introduction: The Basics", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'Introduction The Basics' }, user: user).call
          expect(service.workshops).to include(workshop)
        end

        it "finds workshops with plus signs when searching without them" do
          workshop = create(:workshop, :published, title: "Arts + Crafts", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'Arts Crafts' }, user: user).call
          expect(service.workshops).to include(workshop)
        end

        it "finds workshops with exclamation marks when searching without them" do
          workshop = create(:workshop, :published, title: "Create!", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'Create' }, user: user).call
          expect(service.workshops).to include(workshop)
        end

        it "finds workshops with question marks when searching without them" do
          workshop = create(:workshop, :published, title: "What is Dance?", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'What is Dance' }, user: user).call
          expect(service.workshops).to include(workshop)
        end

        it "finds workshops with commas when searching without them" do
          workshop = create(:workshop, :published, title: "Draw, Paint, Create", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'Draw Paint Create' }, user: user).call
          expect(service.workshops).to include(workshop)
        end

        it "finds workshops with parentheses when searching without them" do
          workshop = create(:workshop, :published, title: "Weaving (Advanced)", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'Weaving Advanced' }, user: user).call
          expect(service.workshops).to include(workshop)
        end

        it "finds workshops with ellipsis when searching without it" do
          workshop = create(:workshop, :published, title: "Creating…Discovering", year: 2025, month: 10)

          service = WorkshopSearchService.new({ title: 'CreatingDiscovering' }, user: user).call
          expect(service.workshops).to include(workshop)
        end

        it "finds all variants of hyphenated/spaced/joined words" do
          hyphenated = create(:workshop, :published, title: "Self-Care Workshop", year: 2025, month: 10)
          spaced = create(:workshop, :published, title: "Self Care Workshop", year: 2025, month: 11)
          joined = create(:workshop, :published, title: "Selfcare Workshop", year: 2025, month: 12)

          # Searching with spaces finds all three
          service = WorkshopSearchService.new({ title: 'Self Care' }, user: user).call
          expect(service.workshops).to include(hyphenated, spaced, joined)

          # Searching with hyphen finds all three
          service = WorkshopSearchService.new({ title: 'Self-Care' }, user: user).call
          expect(service.workshops).to include(hyphenated, spaced, joined)

          # Searching joined finds all three
          service = WorkshopSearchService.new({ title: 'SelfCare' }, user: user).call
          expect(service.workshops).to include(hyphenated, spaced, joined)
        end
      end

      context "query search" do
        let!(:workshop_with_hyphen_content) do
          create(:workshop, :published, title: "Test Workshop", rhino_objective: "Learn about self-care", year: 2025, month: 11)
        end
        let!(:workshop_without_hyphen_content) do
          create(:workshop, :published, title: "Another Workshop", rhino_objective: "Learn about selfcare", year: 2025, month: 12)
        end
        let!(:workshop_with_ampersand_content) do
          create(:workshop, :published, title: "Third Workshop", rhino_objective: "Arts & crafts therapy", year: 2026, month: 1)
        end

        it "finds all variants of hyphenated/spaced/joined content" do
          # "selfcare" finds both hyphenated and joined
          service = WorkshopSearchService.new({ query: 'selfcare' }, user: user).call
          expect(service.workshops).to include(workshop_with_hyphen_content)
          expect(service.workshops).to include(workshop_without_hyphen_content)

          # "self-care" finds both
          service = WorkshopSearchService.new({ query: 'self-care' }, user: user).call
          expect(service.workshops).to include(workshop_with_hyphen_content)
          expect(service.workshops).to include(workshop_without_hyphen_content)

          # "self care" finds both
          service = WorkshopSearchService.new({ query: 'self care' }, user: user).call
          expect(service.workshops).to include(workshop_with_hyphen_content)
          expect(service.workshops).to include(workshop_without_hyphen_content)
        end

        it "finds workshops with ampersands in content when searching without ampersands" do
          service = WorkshopSearchService.new({ query: 'Arts crafts' }, user: user).call
          workshops = service.workshops

          expect(workshops).to include(workshop_with_ampersand_content)
        end
      end
    end
  end
end
