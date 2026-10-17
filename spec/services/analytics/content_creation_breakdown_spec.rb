require "rails_helper"

RSpec.describe Analytics::ContentCreationBreakdown do
  let(:admin) { create(:user, :admin, :with_person) }
  let(:facilitator) { create(:user, :with_person) }

  def row(label, time_range: nil)
    described_class.new(time_range: time_range).groups.flatten.find { |r| r.label == label }
  end

  it "credits user and admin sides that add up to the total" do
    create(:bookmark, user: facilitator)
    create(:bookmark, user: admin)
    create(:bookmark, user: admin)

    bookmarks = row("Bookmarks")

    expect([ bookmarks.user.count, bookmarks.admin.count, bookmarks.total.count ]).to eq([ 1, 2, 3 ])
  end

  it "credits an admin-entered story to its non-admin author" do
    create(:story, created_by: admin, author: facilitator.person)

    stories = row("Stories")

    expect([ stories.user.count, stories.admin.count ]).to eq([ 1, 0 ])
  end

  it "credits an authorless story to whoever created it" do
    create(:story, created_by: admin, author: nil)

    expect(row("Stories").admin.count).to eq(1)
  end

  it "credits a story promoted from an idea to the idea's author and counts the pair once" do
    idea = create(:story_idea, created_by: facilitator)
    create(:story, created_by: admin, author: facilitator.person, story_idea: idea)
    create(:story_idea, created_by: facilitator)

    stories = row("Stories")

    expect(stories.user).to have_attributes(count: 2, promoted_ideas: 1, unpromoted_ideas: 1)
    expect(stories.admin.count).to eq(0)
  end

  it "only counts content created inside the time range" do
    create(:bookmark, user: facilitator, created_at: 2.months.ago)
    create(:bookmark, user: facilitator)

    expect(row("Bookmarks", time_range: 1.month.ago..Time.current).total.count).to eq(1)
  end
end
