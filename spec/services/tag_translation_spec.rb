# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagTranslation do
  let!(:domestic_violence) { create(:sector, :published, name: "Domestic Violence") }
  let!(:education) { create(:sector, :published, name: "Education") }
  let!(:age_range_type) { create(:category_type, name: "AgeRange", published: true) }
  let!(:children) { create(:category, :published, category_type: age_range_type, name: "Children") }
  let!(:teens) { create(:category, :published, category_type: age_range_type, name: "Teens") }

  it "resolves a term by the tag's own name, whatever its case" do
    expect(described_class.new.sector_ids_for("domestic violence")).to eq([ domestic_violence.id ])
  end

  it "resolves a term by an alias recorded for the tag" do
    create(:tag_alias, name: "Student Services", aliasable: education)

    expect(described_class.new.sector_ids_for("student services")).to eq([ education.id ])
  end

  it "reads one term as several tags when both are recorded" do
    create(:tag_alias, name: "C & T", aliasable: children, source: "filemaker")
    create(:tag_alias, name: "C & T", aliasable: teens, source: "filemaker")

    expect(described_class.new.age_group_ids_for("C & T")).to contain_exactly(children.id, teens.id)
  end

  it "splits a repeating field on line breaks and semicolons, not on commas" do
    create(:tag_alias, name: "Community violence (gang violence, mass shootings, etc.)", aliasable: domestic_violence)

    translation = described_class.new
    expect(translation.sector_ids_for("Domestic Violence\nEducation")).to contain_exactly(domestic_violence.id, education.id)
    expect(translation.sector_ids_for("Domestic Violence; Education")).to contain_exactly(domestic_violence.id, education.id)
    expect(translation.sector_ids_for("Community violence (gang violence, mass shootings, etc.)")).to eq([ domestic_violence.id ])
  end

  it "drops a clarifying parenthetical when the term alone resolves" do
    expect(described_class.new.sector_ids_for("Domestic violence (including family violence)")).to eq([ domestic_violence.id ])
  end

  it "counts a term nothing answers to instead of guessing at it" do
    translation = described_class.new

    expect(translation.sector_ids_for("Poverty\nDomestic Violence")).to eq([ domestic_violence.id ])
    expect(translation.unmatched).to eq({ "poverty" => 1 })
  end

  it "keeps a term recorded as ignored out of the unmatched list" do
    create(:tag_alias, name: "Virtually", aliasable: nil, ignored: true)
    translation = described_class.new

    expect(translation.sector_ids_for("Virtually\nDomestic Violence")).to eq([ domestic_violence.id ])
    expect(translation.unmatched).to be_empty
  end

  it "leaves a retired tag out of reach, by name or by alias" do
    retired = create(:sector, :unpublished, name: "Poverty")
    create(:tag_alias, name: "Destitution", aliasable: retired)
    translation = described_class.new

    expect(translation.sector_ids_for("Poverty")).to be_empty
    expect(translation.sector_ids_for("Destitution")).to be_empty
    expect(translation.unmatched).to eq({ "poverty" => 1, "destitution" => 1 })
  end

  it "has nothing to say about a blank value" do
    translation = described_class.new

    expect(translation.sector_ids_for(nil)).to be_empty
    expect(translation.sector_ids_for("  ")).to be_empty
    expect(translation.unmatched).to be_empty
  end
end
