require "rails_helper"

# One shared world exercising every page that shows sectors and age groups:
# orgs roll up only their active facilitators' tags (primary for chips, primary +
# additional for search and the breakdown), while people show and match their own.
RSpec.describe "Organization sector and age-group roll-up", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:age_type) { create(:category_type, name: "AgeRange", published: true) }

  let!(:sectors) { [ "Housing", "Legal", "Education", "Veterans", "Arts", "Mental health" ].index_with { |name| create(:sector, :published, name: name) } }
  let!(:ages) { %w[Children Teens Adults Elders].each.with_index(1).to_h { |name, position| [ name, create(:category, :published, category_type: age_type, name: name, position: position) ] } }

  let!(:harbor) { create(:organization, name: "Harbor House") }
  let!(:beacon) { create(:organization, name: "Beacon Center") }
  let!(:cedar) { create(:organization, name: "Cedar Collective") }

  def person(first_name, sectors: {}, ages: {})
    create(:person, first_name: first_name, last_name: "Example").tap do |record|
      sectors.each { |name, primary| record.sectorable_items.create!(sector: self.sectors.fetch(name), is_primary: primary) }
      ages.each { |name, primary| record.categorizable_items.create!(category: self.ages.fetch(name), is_primary: primary) }
    end
  end

  def affiliate(record, organization, title: Affiliation::FACILITATOR_TITLE, **attrs)
    create(:affiliation, person: record, organization: organization, title: title, **attrs)
  end

  # Primary + additional of each.
  let!(:ana) { person("Ana", sectors: { "Housing" => true, "Legal" => false }, ages: { "Teens" => true, "Adults" => false }) }
  # Primary sector only, no age group.
  let!(:ben) { person("Ben", sectors: { "Education" => true }) }
  # Additional sector only, primary age group only.
  let!(:cleo) { person("Cleo", sectors: { "Veterans" => false }, ages: { "Children" => true }) }
  # Nothing tagged.
  let!(:dev) { person("Dev") }
  # Active, but not a facilitator.
  let!(:eli) { person("Eli", sectors: { "Arts" => true }, ages: { "Elders" => true }) }
  # A facilitator whose affiliation has ended.
  let!(:fay) { person("Fay", sectors: { "Mental health" => true }, ages: { "Elders" => false }) }
  # Several affiliations: active facilitator at Harbor, ended facilitator at Beacon, active director at Cedar.
  let!(:gus) { person("Gus", sectors: { "Housing" => true, "Education" => false }, ages: { "Adults" => true }) }
  # Additional-only tags, sole active facilitator at Beacon.
  let!(:hal) { person("Hal", sectors: { "Legal" => false }, ages: { "Teens" => false }) }

  before do
    [ ana, ben, cleo, dev, gus ].each { |record| affiliate(record, harbor) }
    affiliate(eli, harbor, title: "Director")
    affiliate(fay, harbor, start_date: 3.years.ago, end_date: 1.year.ago)
    affiliate(gus, beacon, start_date: 3.years.ago, end_date: 1.year.ago)
    affiliate(gus, cedar, title: "Director")
    affiliate(hal, beacon)
    sign_in admin
  end

  def body = Capybara.string(response.body)

  describe "organizations index search" do
    def org_names_for(**filters)
      get organizations_path(**filters), headers: { "Turbo-Frame" => "organizations_results" }
      expect(response).to have_http_status(:ok)
      [ harbor, beacon, cedar ].map(&:name).select { |name| response.body.include?(name) }
    end

    it "matches a sector any active facilitator holds, primary or additional" do
      expect(org_names_for(sector_name: "Housing")).to contain_exactly("Harbor House")
      expect(org_names_for(sector_name: "Legal")).to contain_exactly("Harbor House", "Beacon Center")
      expect(org_names_for(sector_name: "Veterans")).to contain_exactly("Harbor House")
      expect(org_names_for(sector_name: "Education")).to contain_exactly("Harbor House")
    end

    it "ignores sectors held only by non-facilitators or ended affiliations" do
      expect(org_names_for(sector_name: "Arts")).to be_empty
      expect(org_names_for(sector_name: "Mental health")).to be_empty
    end

    it "matches an age group any active facilitator holds, primary or additional" do
      expect(org_names_for(age_group_name: "Teens")).to contain_exactly("Harbor House", "Beacon Center")
      expect(org_names_for(age_group_name: "Adults")).to contain_exactly("Harbor House")
      expect(org_names_for(age_group_name: "Children")).to contain_exactly("Harbor House")
      expect(org_names_for(age_group_name: "Elders")).to be_empty
    end
  end

  describe "people index search" do
    def people_for(**filters)
      get people_path(**filters), headers: { "Turbo-Frame" => "people_results" }
      expect(response).to have_http_status(:ok)
      [ ana, ben, cleo, dev, eli, fay, gus, hal ].map(&:first_name).select { |name| response.body.include?("#{name} Example") }
    end

    it "matches anyone holding the sector, primary or additional, whatever their affiliation" do
      expect(people_for(sector_ids: [ sectors["Legal"].id ])).to contain_exactly("Ana", "Hal")
      expect(people_for(sector_ids: [ sectors["Housing"].id ])).to contain_exactly("Ana", "Gus")
      expect(people_for(sector_ids: [ sectors["Arts"].id ])).to contain_exactly("Eli")
      expect(people_for(sector_ids: [ sectors["Mental health"].id ])).to contain_exactly("Fay")
    end

    it "matches anyone holding the age range, primary or additional" do
      expect(people_for(age_range_ids: [ ages["Elders"].id ])).to contain_exactly("Eli", "Fay")
      expect(people_for(age_range_ids: [ ages["Adults"].id ])).to contain_exactly("Ana", "Gus")
      expect(people_for(age_range_ids: [ ages["Teens"].id ])).to contain_exactly("Ana", "Hal")
    end
  end

  describe "organization profile" do
    def starred?(chip) = chip.has_css?("i.fa-star")

    it "shows each active facilitator's primary sector and age group, starred, most-held first" do
      get organization_path(harbor)

      sector_chips = body.all("a[data-sector-name]")
      expect(sector_chips.map { |chip| chip["data-sector-name"] }).to eq([ "Housing", "Education" ])
      expect(sector_chips).to all(satisfy { |chip| starred?(chip) })

      age_chips = %w[Children Teens Adults Elders].filter_map { |name| body.first("a[title='#{name}']", minimum: 0) }
      expect(age_chips.map { |chip| chip["title"] }).to contain_exactly("Children", "Teens", "Adults")
      expect(age_chips).to all(satisfy { |chip| starred?(chip) })
    end

    it "shows nothing for an org whose only active facilitator has no primaries" do
      get organization_path(beacon)

      expect(body).not_to have_css("a[data-sector-name]")
      expect(body).to have_content("None listed by active facilitators.")
    end
  end

  describe "person profile" do
    def sector_chip(name) = body.find("a[data-sector-name='#{name}']")
    def age_chip(name) = body.find("a[title='#{name}']")

    it "stars only the person's primary sector and age group" do
      get person_path(ana)

      expect(sector_chip("Housing")).to have_css("i.fa-star")
      expect(sector_chip("Legal")).not_to have_css("i.fa-star")
      expect(age_chip("Teens")).to have_css("i.fa-star")
      expect(age_chip("Adults")).not_to have_css("i.fa-star")
    end

    it "shows an additional-only sector unstarred beside a primary age group" do
      get person_path(cleo)

      expect(sector_chip("Veterans")).not_to have_css("i.fa-star")
      expect(age_chip("Children")).to have_css("i.fa-star")
    end

    it "shows a person with multiple affiliations their own tags, not any org's" do
      get person_path(gus)

      expect(sector_chip("Housing")).to have_css("i.fa-star")
      expect(sector_chip("Education")).not_to have_css("i.fa-star")
      expect(body).not_to have_css("a[data-sector-name='Legal']")
    end
  end

  describe "populations served breakdown" do
    def rows_for(section_title)
      section = body.all("section").find { |node| node.has_css?("h2", exact_text: section_title) }
      section.all("li").to_h { |li| [ li.find("a").text, li["title"] ] }
    end

    it "totals every tag active facilitators hold, split into primary and additional" do
      get populations_served_organization_path(harbor)

      expect(body).to have_content("Everything the 5 active facilitators at Harbor House")
      expect(rows_for("Sectors")).to eq(
        "Housing" => "2 total · 2 primary · 0 additional",
        "Education" => "2 total · 1 primary · 1 additional",
        "Legal" => "1 total · 0 primary · 1 additional",
        "Veterans" => "1 total · 0 primary · 1 additional"
      )
      expect(rows_for("Age groups served")).to eq(
        "Adults" => "2 total · 1 primary · 1 additional",
        "Children" => "1 total · 1 primary · 0 additional",
        "Teens" => "1 total · 1 primary · 0 additional"
      )
    end

    it "orders by total when asked" do
      get populations_served_organization_path(harbor, sort: "total")

      expect(rows_for("Sectors").keys).to eq(%w[Housing Education Legal Veterans])
      expect(rows_for("Age groups served").keys).to eq(%w[Adults Children Teens])
    end

    it "counts only the active facilitator for an org with an ended one" do
      get populations_served_organization_path(beacon)

      expect(body).to have_content("Everything the 1 active facilitator at Beacon Center")
      expect(rows_for("Sectors")).to eq("Legal" => "1 total · 0 primary · 1 additional")
      expect(rows_for("Age groups served")).to eq("Teens" => "1 total · 0 primary · 1 additional")
    end
  end

  describe "tag search" do
    it "lists each org whose active facilitators hold the tag, with their total" do
      get taggings_path(sector_names_all: "Legal")

      org_cards = body.all("span[title]", text: "Legal").map { |chip| [ chip.text.squish, chip["title"] ] }
      expect(org_cards).to contain_exactly(
        [ "Legal 1*", "1 total · 0 primary · 1 additional" ],
        [ "Legal 1*", "1 total · 0 primary · 1 additional" ]
      )
      expect(body).to have_link("Harbor House", href: organization_path(harbor))
      expect(body).to have_link("Beacon Center", href: organization_path(beacon))
      expect(body).not_to have_link("Cedar Collective")
    end
  end
end
