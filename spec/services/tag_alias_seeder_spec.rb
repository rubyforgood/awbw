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

  it "records a term that names two age groups once for each" do
    described_class.call(quiet: true)

    expect(TagAlias.where(name: "C & T").map { |row| row.aliasable.name }).to contain_exactly("Children", "Teens")
  end

  it "reads serving families as serving every age" do
    described_class.call(quiet: true)

    expect(TagAlias.where(name: "Families").map { |row| row.aliasable.name })
      .to contain_exactly("Children", "Teens", "Adults", "Elders")
  end

  it "reports a term aimed at a retired tag instead of recording an alias that can't resolve" do
    Sector.find_by(name: "Education").update!(published: false)

    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "Student Services")).to be_nil
  end

  it "labels each term with the system it came from" do
    described_class.call(quiet: true)

    expect(TagAlias.find_by(name: "Student Services").source).to eq("filemaker")
    expect(TagAlias.find_by(name: "Homeless services").source).to eq("forms")
    expect(TagAlias.find_by(name: "Grief & Loss").source).to eq("story_share")
    expect(TagAlias.find_by(name: "Grief and loss").source).to eq("portal")
  end

  it "adds nothing on a second run" do
    described_class.call(quiet: true)

    expect { described_class.call(quiet: true) }.not_to change(TagAlias, :count)
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
    expect(translation.sector_ids_for("Virtually")).to be_empty
    expect(translation.unmatched).to be_empty
  end

  it "resolves the archive's own wording once seeded" do
    described_class.call(quiet: true)

    translation = TagTranslation.new
    expect(translation.sector_ids_for("Clinical Setting")).to eq([ Sector.find_by(name: "Mental Health").id ])
    expect(translation.age_group_ids_for("C & T").size).to eq(2)
  end
end
