require "rails_helper"

RSpec.describe AudienceResolver do
  let!(:amy)   { create(:person, first_name: "Amy",   last_name: "User") }
  let!(:aisha) { create(:person, first_name: "Aisha", last_name: "Sharma") }
  let!(:bob)   { create(:person, first_name: "Bob",   last_name: "Jones") }

  def resolve(segments, added: [], excluded: [])
    comp = build(:notification_composition,
                 recipient_segments: segments,
                 recipient_added_ids: added,
                 recipient_excluded_ids: excluded)
    described_class.new(comp).people
  end

  it "unions matches with OR" do
    people = resolve([
      { "field" => "first_name", "value" => "Amy",   "join" => "AND" },
      { "field" => "first_name", "value" => "Aisha", "join" => "OR" }
    ])
    expect(people).to match_array([ amy, aisha ])
  end

  it "intersects matches with AND" do
    people = resolve([
      { "field" => "last_name",  "value" => "Sharma", "join" => "AND" },
      { "field" => "first_name", "value" => "Aisha",  "join" => "AND" }
    ])
    expect(people).to eq([ aisha ])
  end

  it "subtracts matches with AND NOT" do
    people = resolve([
      { "field" => "first_name", "value" => "a",     "join" => "AND" },     # Amy + Aisha
      { "field" => "first_name", "value" => "Aisha", "join" => "AND NOT" }
    ])
    expect(people).to eq([ amy ])
  end

  it "honors the a--b multi-value convention on text fields" do
    people = resolve([ { "field" => "first_name", "value" => "Amy--Bob", "join" => "AND" } ])
    expect(people).to match_array([ amy, bob ])
  end

  it "applies manual add and exclude overrides (add wins)" do
    added = resolve([ { "field" => "first_name", "value" => "Amy", "join" => "AND" } ], added: [ bob.id ])
    expect(added).to match_array([ amy, bob ])

    excluded = resolve([ { "field" => "first_name", "value" => "Amy--Bob", "join" => "AND" } ], excluded: [ bob.id ])
    expect(excluded).to eq([ amy ])
  end

  it "drops matched people who have no email" do
    create(:person, first_name: "Zed", user: nil, email: nil, email_2: nil)
    expect(resolve([ { "field" => "first_name", "value" => "Zed", "join" => "AND" } ])).to be_empty
  end

  it "returns nothing when no segment matches a known field" do
    expect(resolve([ { "field" => "unknown_field", "value" => "x", "join" => "AND" } ])).to be_empty
  end
end
