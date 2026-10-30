require "rails_helper"

RSpec.describe OrganizationServices::WorkshopLogSummary do
  let(:organization) { create(:organization) }
  let(:collage) { create(:workshop) }
  let(:masks) { create(:workshop) }
  let(:summary) { described_class.new(organization) }

  def log(workshop: nil, title: nil, on: Date.current, **counts)
    create(:workshop_log, organization: organization, workshop: workshop, external_workshop_title: title,
           workshop_held_on: on, **counts)
  end

  it "sums participants and counts unique workshops in the database" do
    log(workshop: collage, adults_first_time: 2, adults_ongoing: 1, teens_ongoing: 4)
    log(workshop: collage, children_first_time: 3)
    log(title: "Outside Workshop", adults_ongoing: 5)

    expect(summary.totals).to eq(logs: 3, adults: 8, teens: 4, children: 3, workshops: 2)
  end

  it "groups logs by workshop or outside title, ordered by each group's latest log" do
    older = log(workshop: collage, on: 30.days.ago)
    newer = log(workshop: collage, on: 1.day.ago)
    outside = log(title: "Outside Workshop", on: 10.days.ago)
    mask = log(workshop: masks, on: 20.days.ago)

    expect(summary.groups(page: 1).to_a).to eq([ [ newer, older ], [ outside ], [ mask ] ])
  end

  it "pages through groups, loading only the current page's logs" do
    workshops = create_list(:workshop, described_class::GROUPS_PER_PAGE + 1)
    workshops.each_with_index { |workshop, i| log(workshop: workshop, on: i.days.ago) }

    first_page = summary.groups(page: 1)
    expect(first_page.size).to eq(described_class::GROUPS_PER_PAGE)
    expect(first_page.total_pages).to eq(2)
    expect(summary.groups(page: 2).to_a).to eq([ [ WorkshopLog.find_by(workshop: workshops.last) ] ])
  end

  # The form requires one now, but older logs can carry neither.
  it "keeps legacy logs with neither a workshop nor a title together" do
    untitled = build(:workshop_log, organization: organization, workshop: nil, external_workshop_title: nil)
    untitled.save!(validate: false)
    expect(summary.groups(page: 1).to_a).to eq([ [ untitled ] ])
  end

  # COUNT(DISTINCT) would skip the group whose key is NULL, understating the page
  # count and stranding whatever sits past the last countable group.
  it "counts the legacy group so it still gets a page" do
    described_class::GROUPS_PER_PAGE.times { log(workshop: create(:workshop)) }
    untitled = build(:workshop_log, organization: organization, workshop: nil,
                     external_workshop_title: nil, workshop_held_on: 2.years.ago)
    untitled.save!(validate: false)

    expect(summary.totals[:workshops]).to eq(described_class::GROUPS_PER_PAGE + 1)
    expect(summary.groups(page: 1).total_pages).to eq(2)
    expect(summary.groups(page: 2).to_a).to eq([ [ untitled ] ])
  end

  # The grouping keys come back from a case-insensitive collation, so a title typed
  # two ways is one group and must not lose either spelling's logs.
  it "folds outside titles that differ only in case into one group" do
    shouted = log(title: "Mask Making", on: 1.day.ago)
    quiet = log(title: "mask making", on: 2.days.ago)

    expect(summary.totals[:workshops]).to eq(1)
    expect(summary.groups(page: 1).to_a).to eq([ [ shouted, quiet ] ])
  end

  describe "#logs_for" do
    it "returns one workshop's logs, newest first" do
      older = log(workshop: collage, on: 10.days.ago)
      newer = log(workshop: collage, on: 1.day.ago)
      log(workshop: masks)

      expect(summary.logs_for(workshop_id: collage.id).to_a).to eq([ newer, older ])
    end

    it "returns an outside title's logs" do
      outside = log(title: "Outside Workshop")
      log(workshop: collage)

      expect(summary.logs_for(external_title: "Outside Workshop").to_a).to eq([ outside ])
    end

    it "returns nil when neither is named" do
      log(workshop: collage)

      expect(summary.logs_for).to be_nil
    end
  end
end
