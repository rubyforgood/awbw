# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagTranslation do
  let!(:domestic_violence) { create(:sector, :published, name: "Domestic Violence") }
  let!(:education) { create(:sector, :published, name: "Education") }
  let!(:age_range_type) { create(:category_type, name: "AgeRange", published: true) }
  let!(:children) { create(:category, :published, category_type: age_range_type, name: "Children") }
  let!(:teens) { create(:category, :published, category_type: age_range_type, name: "Teens") }
  let!(:elders) { create(:category, :published, category_type: age_range_type, name: "Elders") }

  it "resolves a term by the tag's own name, whatever its case" do
    expect(described_class.new.resolve("domestic violence").sector_ids).to eq([ domestic_violence.id ])
  end

  it "resolves a term by an alias recorded for the tag" do
    create(:tag_alias, name: "Student Services", aliasable: education)

    expect(described_class.new.resolve("student services").sector_ids).to eq([ education.id ])
  end

  it "reads one term as several tags when both are recorded" do
    create(:tag_alias, name: "C & T", aliasable: children, source: "filemaker")
    create(:tag_alias, name: "C & T", aliasable: teens, source: "filemaker")

    expect(described_class.new.resolve("C & T").age_group_ids).to contain_exactly(children.id, teens.id)
  end

  it "splits a repeating field on line breaks and semicolons, not on commas" do
    create(:tag_alias, name: "Community violence (gang violence, mass shootings, etc.)", aliasable: domestic_violence)

    translation = described_class.new
    expect(translation.resolve("Domestic Violence\nEducation").sector_ids).to contain_exactly(domestic_violence.id, education.id)
    expect(translation.resolve("Domestic Violence; Education").sector_ids).to contain_exactly(domestic_violence.id, education.id)
    expect(translation.resolve("Community violence (gang violence, mass shootings, etc.)").sector_ids).to eq([ domestic_violence.id ])
  end

  it "drops a clarifying parenthetical when the term alone resolves" do
    expect(described_class.new.resolve("Domestic violence (including family violence)").sector_ids).to eq([ domestic_violence.id ])
  end

  it "counts a term nothing answers to instead of guessing at it" do
    translation = described_class.new

    expect(translation.resolve("Poverty\nDomestic Violence").sector_ids).to eq([ domestic_violence.id ])
    expect(translation.unmatched).to eq({ "poverty" => 1 })
  end

  it "keeps a term recorded as ignored out of the unmatched list" do
    create(:tag_alias, name: "Virtually", aliasable: nil, ignored: true)
    translation = described_class.new

    expect(translation.resolve("Virtually\nDomestic Violence").sector_ids).to eq([ domestic_violence.id ])
    expect(translation.unmatched).to be_empty
  end

  it "won't reach a retired tag by its own name" do
    create(:sector, :unpublished, name: "Poverty")
    translation = described_class.new

    expect(translation.resolve("Poverty").sector_ids).to be_empty
    expect(translation.unmatched).to eq({ "poverty" => 1 })
  end

  it "reaches a retired tag an alias deliberately points at" do
    retired = create(:sector, :unpublished, name: "Poverty")
    create(:tag_alias, name: "Poverty", aliasable: retired)
    translation = described_class.new

    expect(translation.resolve("Poverty").sector_ids).to eq([ retired.id ])
    expect(translation.unmatched).to be_empty
  end

  it "keeps an age-group alias from reaching a category of another kind" do
    population_type = create(:category_type, name: "StoryPopulation", published: true)
    families = create(:category, :published, category_type: population_type, name: "Families_")
    create(:tag_alias, name: "Family windows", aliasable: families)

    expect(described_class.new.resolve("Family windows").age_group_ids).to be_empty
  end

  it "answers with an age group for a term that sat in a sector field" do
    create(:tag_alias, name: "Elder Abuse", aliasable: elders)
    tags = described_class.new.resolve("Elder Abuse")

    expect(tags.sector_ids).to be_empty
    expect(tags.age_group_ids).to eq([ elders.id ])
  end

  it "counts a term once, however many vocabularies miss it" do
    translation = described_class.new
    translation.resolve("Poverty")
    translation.resolve("Poverty")

    expect(translation.unmatched).to eq({ "poverty" => 2 })
  end

  it "has nothing to say about a blank value" do
    translation = described_class.new

    expect(translation.resolve(nil).sector_ids).to be_empty
    expect(translation.resolve("  ").age_group_ids).to be_empty
    expect(translation.unmatched).to be_empty
  end
end
