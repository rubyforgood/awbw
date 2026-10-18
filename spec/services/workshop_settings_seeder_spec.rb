# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkshopSettingsSeeder do
  def settings_type = CategoryType.find_by(name: "WorkshopEnvironment")

  it "creates the profile workshop settings type and its options, in order" do
    described_class.call

    expect(settings_type).to have_attributes(display_text: "Workshop Settings", profile_specific: true,
                                             story_specific: false, published: true)
    expect(settings_type.categories.order(:position).pluck(:name)).to eq(described_class::SETTINGS.map(&:first))
    expect(settings_type.categories.find_by(name: "Clinical setting").description).to eq("Community mental health, outpatient, etc")
  end

  it "adds nothing on a second run" do
    described_class.call

    expect { described_class.call }.not_to change(Category, :count)
  end

  it "renames an option seeded with its examples in the label, keeping its taggings" do
    type = create(:category_type, name: "WorkshopEnvironment")
    legacy = create(:category, category_type: type, name: "Clinical setting (community mental health, outpatient, etc)")

    described_class.call

    expect(legacy.reload).to have_attributes(name: "Clinical setting", published: true)
  end

  it "unpublishes an option no longer offered instead of deleting it" do
    type = create(:category_type, name: "WorkshopEnvironment")
    retired = create(:category, :published, category_type: type, name: "Community-based")

    described_class.call

    expect(retired.reload.published).to be(false)
  end
end
