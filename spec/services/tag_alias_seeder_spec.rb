# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAliasSeeder do
  let!(:age_range_type) { create(:category_type, name: "AgeRange", published: true) }

  before do
    Sector::SECTOR_TYPES.each { |name| create(:sector, :published, name: name) }
    %w[Children Teens Adults Elders].each { |name| create(:category, :published, category_type: age_range_type, name: name) }
  end

  it "records every term the tables name, pointing at the tag it resolves to" do
    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "Student Services").aliasable).to eq(Sector.find_by(name: "Education"))
    expect(TagAlias.find_by(name: "Clinical Setting").aliasable).to eq(Sector.find_by(name: "Mental Health"))
    expect(TagAlias.find_by(name: "Advocacy").aliasable).to eq(Sector.find_by(name: "Systems/Policy Change"))
    expect(TagAlias.find_by(name: "Child abuse").aliasable).to eq(Sector.find_by(name: "Child Abuse/Neglect"))
    expect(TagAlias.find_by(name: "Homeless services").aliasable).to eq(Sector.find_by(name: "Homelessness"))
  end

  it "resolves the translation sheet's own wording of a term" do
    described_class.call(quiet: true)
    translation = TagTranslation.new

    expect(translation.resolve("Racism & Marginalization").sector_ids).to eq([ Sector.find_by(name: "Racial/Social Justice").id ])
    expect(translation.resolve("Sytems/Policy Change").sector_ids).to eq([ Sector.find_by(name: "Systems/Policy Change").id ])
  end

  it "records a term that names two age groups once for each" do
    described_class.call(quiet: true)

    expect(TagAlias.where(name: "C & T").map { |row| row.aliasable.name }).to contain_exactly("Children", "Teens")
  end

  it "reads serving families as serving every age" do
    described_class.call(quiet: true)

    expect(TagAlias.where(name: "Families").map { |row| row.aliasable.name })
      .to contain_exactly("Children", "Teens", "Adults", "Elders")
  end

  it "reports a term whose tag isn't published, when nothing says to point at a retired one" do
    Sector.find_by(name: "Education").update!(published: false)

    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "Student Services")).to be_nil
  end

  it "points the archive's Poverty at the retired sector that already carries its taggings" do
    retired = create(:sector, :unpublished, name: "Poverty")

    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "Poverty").aliasable).to eq(retired)
    expect(TagTranslation.new.resolve("Poverty").sector_ids).to eq([ retired.id ])
  end

  it "reads a cell naming several sectors as all of them" do
    described_class.call(quiet: true)

    expect(TagAlias.where(name: "Sexual Assault & Domestic Violence").map { |row| row.aliasable.name })
      .to contain_exactly("Sexual Assault", "Domestic Violence")
    expect(TagTranslation.new.resolve("DV/SA/other related crimes").sector_ids.size).to eq(2)
  end

  it "reads a life experience or service area that means an age group" do
    described_class.call(quiet: true)

    translation = TagTranslation.new
    expect(translation.resolve("Elder Abuse").age_group_ids).to eq([ Category.find_by(name: "Elders").id ])
    expect(translation.resolve("Children's Services").age_group_ids).to eq([ Category.find_by(name: "Children").id ])
    expect(translation.resolve("Elder Abuse").sector_ids).to be_empty
  end

  it "leaves war untagged, as decided" do
    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "People Who Have Experienced War")).to have_attributes(aliasable: nil, ignored: true)

    translation = TagTranslation.new
    expect(translation.resolve("People Who Have Experienced War").sector_ids).to be_empty
    expect(translation.unmatched).to be_empty
  end

  it "records an answer that says nothing as naming nothing" do
    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "n/a")).to have_attributes(aliasable: nil, ignored: true)

    translation = TagTranslation.new
    expect(translation.resolve("n/a\nunsure\nIn person").sector_ids).to be_empty
    expect(translation.unmatched).to be_empty
  end

  it "labels each term with the system it came from" do
    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "Student Services").source).to eq("filemaker")
    expect(TagAlias.find_by(name: "Homeless services").source).to eq("forms")
    expect(TagAlias.find_by(name: "Grief & Loss").source).to eq("story_share")
    expect(TagAlias.find_by(name: "Grief and loss").source).to eq("portal")
  end

  it "marks a read of free text as proposed, and a decision as decided" do
    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "Immigration Clinic")).to have_attributes(proposed: true, ignored: false)
    expect(TagAlias.find_by(name: "Libraries")).to have_attributes(proposed: true, ignored: true)
    expect(TagAlias.find_by(name: "Student Services").proposed).to be false
    expect(TagAlias.find_by(name: "Virtually").proposed).to be false
    expect(TagAlias.proposed.count).to be > 50
  end

  it "resolves a proposed read, so an import doesn't lose it while staff review" do
    described_class.call(quiet: true)

    translation = TagTranslation.new
    tags = translation.resolve("Immigration Clinic")
    expect(tags.sector_ids).to eq([ Sector.find_by(name: "Immigration").id ])
    expect(translation.resolve("Libraries").sector_ids).to be_empty
    expect(translation.unmatched).to be_empty
  end

  it "reads a free-text answer that names several sectors and the ages it serves" do
    described_class.call(quiet: true)

    tags = TagTranslation.new.resolve("1:1 children and youth who experience domestic violence, dating violence, or sexual abuse")
    expect(tags.sector_ids).to match_array(Sector.where(name: [ "Domestic Violence", "Sexual Assault", "Child Abuse/Neglect" ]).ids)
    expect(tags.age_group_ids).to match_array(Category.where(name: %w[Children Teens]).ids)
  end

  it "adds nothing on a second run" do
    described_class.call(quiet: true)

    expect { described_class.call(quiet: true) }.not_to change(TagAlias, :count)
  end

  it "withdraws a proposed read the tables no longer name, so an edited proposal takes effect" do
    stale = create(:tag_alias, name: "Inpatient Psychiatric Hopital", aliasable: Sector.find_by(name: "Health/Medical"),
                               source: "filemaker", proposed: true)
    stale_ignored = create(:tag_alias, name: "Family Resource Centers", aliasable: nil, ignored: true,
                                       source: "filemaker", proposed: true)

    described_class.call(quiet: true)

    expect(TagAlias.exists?(stale.id)).to be false
    expect(TagAlias.exists?(stale_ignored.id)).to be false
    expect(TagTranslation.new.resolve("Family Resource Centers").sector_ids).to eq([ Sector.find_by(name: "Community Building").id ])
  end

  it "keeps a proposal staff have validated even once the tables drop it" do
    validated = create(:tag_alias, name: "Inpatient Psychiatric Hopital", aliasable: Sector.find_by(name: "Health/Medical"),
                                   source: "filemaker", proposed: false)

    described_class.call(quiet: true)

    expect(TagAlias.exists?(validated.id)).to be true
  end

  it "withdraws nothing while a proposal's tag is missing, since that proposal couldn't be matched" do
    stale = create(:tag_alias, name: "Inpatient Psychiatric Hopital", aliasable: Sector.find_by(name: "Health/Medical"),
                               source: "filemaker", proposed: true)
    Sector.find_by(name: "Community Building").destroy

    described_class.call(quiet: true)

    expect(TagAlias.exists?(stale.id)).to be true
  end

  it "leaves a term an admin recorded by hand alone" do
    sexual_assault = Sector.find_by(name: "Sexual Assault")
    admin_alias = create(:tag_alias, name: "Student Services", aliasable: sexual_assault, source: "portal")

    described_class.call(quiet: true)

    expect(admin_alias.reload.aliasable).to eq(sexual_assault)
    expect(TagAlias.where(name: "Student Services").count).to eq(2)
  end

  it "reports a term whose tag isn't seeded yet instead of inventing it" do
    Sector.find_by(name: "Education").destroy

    expect { described_class.call(quiet: true) }.not_to raise_error
    expect(TagAlias.find_by(name: "Student Services")).to be_nil
  end

  it "records a setting that names nothing as decided, not as a gap" do
    described_class.call(quiet: true)

    virtually = TagAlias.find_by(name: "Virtually")
    expect(virtually).to have_attributes(aliasable: nil, ignored: true)

    translation = TagTranslation.new
    expect(translation.resolve("Virtually").sector_ids).to be_empty
    expect(translation.unmatched).to be_empty
  end

  it "resolves the archive's own wording once seeded" do
    described_class.call(quiet: true)

    translation = TagTranslation.new
    expect(translation.resolve("Clinical Setting").sector_ids).to eq([ Sector.find_by(name: "Mental Health").id ])
    expect(translation.resolve("C & T").age_group_ids.size).to eq(2)
  end
end
