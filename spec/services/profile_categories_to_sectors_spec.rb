# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfileCategoriesToSectors do
  let!(:health) { create(:sector, :published, name: "Health/Medical") }
  let!(:education) { create(:sector, :published, name: "Education") }
  let(:settings_type) { create(:category_type, :published, name: "WorkshopEnvironment", profile_specific: true) }
  let(:hospitals) { create(:category, :published, category_type: settings_type, name: "Hospitals") }
  let(:educational) { create(:category, :published, category_type: settings_type, name: "Educational setting") }
  let(:virtually) { create(:category, :published, category_type: settings_type, name: "Virtually") }
  let(:person) { create(:person) }

  before do
    create(:tag_alias, name: "Hospitals", aliasable: health)
    create(:tag_alias, name: "Educational Setting", aliasable: education)
    create(:tag_alias, name: "Virtually", aliasable: nil, ignored: true)
  end

  def tag(record, category)
    create(:categorizable_item, categorizable: record, category: category)
  end

  it "adds each translated tag as an additional sector, whatever the alias's case" do
    tag(person, hospitals)
    tag(person, educational)

    result = described_class.new.call

    expect(person.sectorable_items.reload.map { |item| [ item.sector, item.is_primary ] })
      .to contain_exactly([ health, false ], [ education, false ])
    expect(result).to have_attributes(added: 2, people: 1)
  end

  it "keeps the category tags" do
    tag(person, hospitals)

    described_class.new.call

    expect(person.categories.reload).to include(hospitals)
  end

  it "leaves a sector the person already carries as it is" do
    create(:sectorable_item, sectorable: person, sector: health, is_primary: true)
    tag(person, hospitals)

    expect(described_class.new.call.added).to eq(0)
    expect(person.sectorable_items.reload.sole.is_primary).to be(true)
  end

  it "adds nothing on a second run" do
    tag(person, hospitals)
    described_class.new.call

    expect { described_class.new.call }.not_to change(SectorableItem, :count)
  end

  it "writes nothing on a dry run" do
    tag(person, hospitals)

    expect { described_class.new(dry_run: true).call }.not_to change(SectorableItem, :count)
  end

  it "skips ignored terms and reports ones nothing translates" do
    tag(person, virtually)
    tag(person, create(:category, :published, category_type: settings_type, name: "Horse barn"))

    result = described_class.new.call

    expect(result.added).to eq(0)
    expect(result.unmatched).to eq("horse barn" => 1)
  end

  it "counts organization tags without converting them" do
    organization = create(:organization)
    tag(organization, hospitals)

    result = described_class.new.call

    expect(result.organization_tags).to eq(1)
    expect(organization.sectorable_items.reload).to be_empty
  end

  it "ignores age ranges and categories that aren't profile-specific" do
    age_type = create(:category_type, :published, name: "AgeRange", profile_specific: true)
    general_type = create(:category_type, :published, name: "ArtType")
    tag(person, create(:category, :published, category_type: age_type, name: "Hospitals"))
    tag(person, create(:category, :published, category_type: general_type, name: "Educational setting"))

    expect(described_class.new.call.added).to eq(0)
  end
end
