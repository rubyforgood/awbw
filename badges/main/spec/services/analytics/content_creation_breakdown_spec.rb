require "rails_helper"

RSpec.describe Analytics::ContentCreationBreakdown do
  let(:admin) { create(:user, :admin, :with_person) }
  let(:facilitator) { create(:user, :with_person) }
  let(:workshop) { create(:workshop, created_by: admin) }

  def breakdown(time_range: nil)
    described_class.new(time_range: time_range)
  end

  def row(label, time_range: nil)
    breakdown(time_range: time_range).groups.flatten.find { |r| r.label == label }
  end

  def sides(label, time_range: nil)
    found = row(label, time_range: time_range)
    [ found.user.count, found.admin.count ]
  end

  describe "#groups" do
    it "lists the facilitator-facing content first and the admin-managed libraries after" do
      labels = breakdown.groups.map { |group| group.map(&:label) }

      expect(labels).to eq([
        [ "Bookmarks", "Quotes", "Stories", "Workshops", "Variations", "Workshop logs" ],
        [ "Resources", "Community news", "Events", "Video recordings" ]
      ])
    end

    it "has user and admin sides that add up to the total on every row" do
      create(:bookmark, user: facilitator, bookmarkable: workshop)
      create(:bookmark, user: admin, bookmarkable: workshop)
      create(:quote, created_by: admin)
      create(:story, created_by: admin, author: facilitator.person, workshop: workshop)
      create(:story_idea, created_by: facilitator, workshop: workshop)
      create(:resource, created_by: admin)
      create(:event, created_by: facilitator)

      breakdown.groups.flatten.each do |r|
        expect(r.user.count + r.admin.count).to eq(r.total.count), "#{r.label} sides don't sum to its total"
      end
    end
  end

  describe "crediting" do
    it "credits bookmarks to the bookmarking account" do
      create(:bookmark, user: facilitator, bookmarkable: workshop)
      create_list(:bookmark, 2, user: admin, bookmarkable: workshop)

      expect(sides("Bookmarks")).to eq([ 1, 2 ])
    end

    it "credits an admin-entered record to its non-admin author" do
      create(:story, created_by: admin, author: facilitator.person, workshop: workshop)

      expect(sides("Stories")).to eq([ 1, 0 ])
    end

    it "credits a facilitator-entered record to its admin author" do
      create(:quote, created_by: facilitator, author: admin.person)

      expect(sides("Quotes")).to eq([ 0, 1 ])
    end

    it "credits an authorless record to whoever created it" do
      create(:story, created_by: admin, author: nil, workshop: workshop)
      create(:quote, created_by: facilitator, author: nil)

      expect(sides("Stories")).to eq([ 0, 1 ])
      expect(sides("Quotes")).to eq([ 1, 0 ])
    end

    it "credits an author with no account to the user side" do
      create(:story, created_by: admin, author: create(:person), workshop: workshop)

      expect(sides("Stories")).to eq([ 1, 0 ])
    end

    it "credits a record with no author and no creator to the user side" do
      create(:video_recording)

      expect(sides("Video recordings")).to eq([ 1, 0 ])
    end

    it "credits records without an author column by their creator" do
      create(:event, created_by: admin)
      create(:event, created_by: facilitator)

      expect(sides("Events")).to eq([ 1, 1 ])
    end
  end

  describe "ideas and the content they become" do
    it "counts a promoted story idea once, credited to the idea's author" do
      idea = create(:story_idea, created_by: facilitator, workshop: workshop)
      create(:story, created_by: admin, author: facilitator.person, story_idea: idea, workshop: workshop)

      stories = row("Stories")

      expect(stories.user).to have_attributes(count: 1, promoted_ideas: 1, unpromoted_ideas: 0)
      expect(stories.admin.count).to eq(0)
    end

    it "counts ideas not yet promoted alongside the published records" do
      create(:story_idea, created_by: facilitator, workshop: workshop)
      create(:story, created_by: admin, workshop: workshop)

      stories = row("Stories")

      expect(stories.user).to have_attributes(count: 1, promoted_ideas: 0, unpromoted_ideas: 1)
      expect(stories.admin).to have_attributes(count: 1, promoted_ideas: 0, unpromoted_ideas: 0)
      expect(stories.total).to have_attributes(count: 2, promoted_ideas: 0, unpromoted_ideas: 1)
    end

    it "folds promoted workshop ideas into the Workshops row" do
      idea = create(:workshop_idea, created_by: facilitator)
      create(:workshop, created_by: admin, author: facilitator.person, workshop_idea: idea)
      create(:workshop_idea, created_by: facilitator, title: "Unpromoted idea")

      expect(row("Workshops").user).to have_attributes(count: 2, promoted_ideas: 1, unpromoted_ideas: 1)
    end

    it "folds promoted variation ideas into the Variations row" do
      idea = create(:workshop_variation_idea, created_by: facilitator, workshop: workshop)
      create(:workshop_variation, created_by: admin, author: facilitator.person,
                                  workshop_variation_idea: idea, workshop: workshop)

      variations = row("Variations")

      expect(variations.user).to have_attributes(count: 1, promoted_ideas: 1, unpromoted_ideas: 0)
      expect(variations.admin.count).to eq(0)
    end

    it "credits an idea an admin submitted to the admin side" do
      create(:story_idea, created_by: admin, workshop: workshop)

      expect(row("Stories").admin).to have_attributes(count: 1, unpromoted_ideas: 1)
    end
  end

  describe "time range" do
    let(:past_month) { 1.month.ago..Time.current }

    it "only counts content created inside the range" do
      create(:bookmark, user: facilitator, bookmarkable: workshop, created_at: 2.months.ago)
      create(:bookmark, user: facilitator, bookmarkable: workshop)

      expect(row("Bookmarks", time_range: past_month).total.count).to eq(1)
    end

    it "counts everything when the range is nil (all time)" do
      create(:bookmark, user: facilitator, bookmarkable: workshop, created_at: 2.years.ago)
      create(:bookmark, user: facilitator, bookmarkable: workshop)

      expect(row("Bookmarks").total.count).to eq(2)
    end

    it "counts a story promoted in range from an older idea once, as a promotion" do
      idea = create(:story_idea, created_by: facilitator, workshop: workshop, created_at: 2.months.ago)
      create(:story, created_by: admin, author: facilitator.person, story_idea: idea, workshop: workshop)

      expect(row("Stories", time_range: past_month).total)
        .to have_attributes(count: 1, promoted_ideas: 1, unpromoted_ideas: 0)
    end

    it "ignores promotions of ideas when the promoted record falls outside the range" do
      idea = create(:story_idea, created_by: facilitator, workshop: workshop, created_at: 3.months.ago)
      create(:story, created_by: admin, author: facilitator.person, story_idea: idea, workshop: workshop,
                     created_at: 2.months.ago)

      expect(row("Stories", time_range: past_month).total)
        .to have_attributes(count: 0, promoted_ideas: 0, unpromoted_ideas: 0)
    end
  end
end
