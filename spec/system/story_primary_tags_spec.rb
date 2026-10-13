require "rails_helper"

RSpec.describe "Story primary sector and category stars", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:health) { create(:sector, :published, name: "Healthcare") }
  let!(:education) { create(:sector, :published, name: "Education") }
  let(:population) { create(:category_type, :published, name: "StoryPopulation", story_specific: true) }
  let!(:children) { create(:category, :published, name: "Children", category_type: population) }
  let!(:teens) { create(:category, :published, name: "Teens", category_type: population) }
  let(:story) { create(:story, :published) }

  before { sign_in admin }

  def star(kind, record)
    find("label:has(#story_primary_#{kind}_id_#{record.id})")
  end

  def member(kind, record)
    find("#story_#{kind}_ids_#{record.id}", visible: :all)
  end

  def primary(kind, record)
    find("#story_primary_#{kind}_id_#{record.id}", visible: :all)
  end

  it "keeps one starred sector, checks the starred tag, and saves the primaries" do
    visit edit_story_path(story)

    star(:sector, health).click
    expect(member(:sector, health)).to be_checked

    star(:sector, education).click
    expect(primary(:sector, health)).not_to be_checked
    expect(primary(:sector, education)).to be_checked

    star(:category, teens).click
    expect(member(:category, teens)).to be_checked

    find(".action-buttons [type=submit]").click

    expect(page).to have_current_path(story_path(story), ignore_query: true)
    story.reload
    expect(story.sectors).to contain_exactly(health, education)
    expect(story.primary_sector).to eq(education)
    expect(story.primary_category).to eq(teens)
  end

  it "clears the star when its tag is unchecked" do
    story.sectorable_items.create!(sector: health, is_primary: true)

    visit edit_story_path(story)
    expect(primary(:sector, health)).to be_checked

    find("label[for='story_sector_ids_#{health.id}']").click

    expect(primary(:sector, health)).not_to be_checked
  end
end
