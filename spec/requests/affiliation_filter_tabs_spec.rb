require "rails_helper"

# The Active/Inactive split is server-rendered — the browser only toggles which
# group is shown, via :has() on two detached radios. See spec/system for the
# toggling itself.
RSpec.describe "the Active/Inactive split on the affiliation editor", type: :request do
  let(:person) { create(:person) }
  let!(:current) do
    create(:affiliation, person: person, organization: create(:organization),
                         title: "Facilitator", start_date: 2.years.ago.to_date)
  end
  let!(:ended) do
    create(:affiliation, person: person, organization: create(:organization), title: "Facilitator",
                         start_date: 3.years.ago.to_date, end_date: 1.year.ago.to_date)
  end

  before { sign_in create(:user, :admin) }

  def parsed = Nokogiri::HTML(response.body)

  def rows_in(id)
    parsed.css("##{id} [data-paginated-fields-target='item']")
  end

  it "puts each row in the group the server bucketed it into" do
    get edit_person_path(person)

    expect(rows_in("person_affiliation_rows_active").to_s).to include(current.organization.name)
    expect(rows_in("person_affiliation_rows_inactive").to_s).to include(ended.organization.name)
    expect(rows_in("person_affiliation_rows_active").to_s).not_to include(ended.organization.name)
  end

  it "counts each bucket in its tab label" do
    get edit_person_path(person)

    expect(parsed.at_css("label[for='aff-tab-active']").text.split.last).to eq("1")
    expect(parsed.at_css("label[for='aff-tab-inactive']").text.split.last).to eq("1")
  end

  it "keeps the tab radios out of the form so they never submit" do
    get edit_person_path(person)

    parsed.css("input[name='affiliation_tab']").each do |radio|
      expect(radio["form"]).to eq("affiliation_tab_none")
      expect(parsed.at_css("##{radio['form']}")).to be_nil
    end
  end

  # Two Tailwind traps: `_` becomes a space inside an arbitrary value, so an
  # underscored id compiles to a selector matching nothing; and an UNNAMED group
  # here collides with each row's comment-icon group, popping every tooltip at once.
  it "uses hyphenated radio ids and a named group so the :has() selectors compile and stay scoped" do
    get edit_person_path(person)

    expect(parsed.css("input[name='affiliation_tab']").map { |r| r["id"] })
      .to all(match(/\A[a-z-]+\z/))
    expect(parsed.at_css("[data-affiliation-dates-target='affiliationsContainer']")["class"])
      .to include("group/afftabs")
    expect(response.body).to include("group-has-[#aff-tab-inactive:checked]/afftabs:hidden")
  end

  it "still submits every row, both buckets, with distinct indices" do
    get edit_person_path(person)

    ids = parsed.css("input[name^='person[affiliations_attributes]'][name$='[id]']").map { |i| i["value"] }
    expect(ids).to contain_exactly(current.id.to_s, ended.id.to_s)

    indices = parsed.css("input[name^='person[affiliations_attributes]']")
      .map { |i| i["name"][/\[affiliations_attributes\]\[([^\]]+)\]/, 1] }.uniq
    expect(indices.size).to eq(2)
  end

  it "adds new rows into the active group only" do
    get edit_person_path(person)

    adder = parsed.at_css("[data-association-insertion-node]")
    expect(adder["data-association-insertion-node"]).to eq("#person_affiliation_rows_active")
  end

  it "does the same on the organization editor" do
    get edit_organization_path(current.organization)

    expect(parsed.at_css("#organization_affiliation_rows_active")).to be_present
    expect(parsed.at_css("#organization_affiliation_rows_inactive")).to be_present
  end

  it "buckets by the flag, not just the dates" do
    current.inactive_supplied = true
    current.update!(inactive: true)

    get edit_person_path(person)

    expect(parsed.at_css("label[for='aff-tab-active']").text.split.last).to eq("0")
    expect(rows_in("person_affiliation_rows_inactive").size).to eq(2)
  end
end
