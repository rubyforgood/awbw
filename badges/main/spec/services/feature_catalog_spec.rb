require "rails_helper"

RSpec.describe FeatureCatalog do
  describe "#import!" do
    let(:seed_dir) { Pathname(Dir.mktmpdir("features_seed")) }

    before do
      seed_dir.join("2026-08-01-seed-feature-one.yml").write(<<~YAML)
        name: "Seed feature one"
        area: events
        display_status: user_facing
        summary: "First seeded feature."
        released_on: 2026-08-01
        action_path: "/events"
        pr_number: 1234
        pro_tips:
          - "Tip A"
          - "Tip B"
        external_url: "https://docs.example.com/one"
        description: "<p>Longer write-up.</p>"
      YAML
      seed_dir.join("2026-08-05-seed-feature-two.yml").write(<<~YAML)
        name: "Seed feature two"
        area: scholarships
        display_status: admin_facing
        summary: "Second seeded feature."
        released_on: 2026-08-05
      YAML
      seed_dir.join("README.md").write("Not a seed.")
    end

    after { FileUtils.remove_entry(seed_dir) }

    subject(:catalog) { described_class.new(dir: seed_dir) }

    it "creates a Feature per seed entry" do
      expect { catalog.import! }.to change(Feature, :count).by(2)
    end

    it "reports how many were created and updated" do
      result = catalog.import!
      expect(result.created).to eq(2)
      expect(result.updated).to eq(0)
      expect(result.total).to eq(2)
    end

    it "maps every field, joining pro_tips with newlines" do
      catalog.import!
      feature = Feature.find_by(name: "Seed feature one")

      expect(feature).to have_attributes(
        area: "events",
        display_status: "user_facing",
        summary: "First seeded feature.",
        released_on: Date.new(2026, 8, 1),
        external_url: "https://docs.example.com/one",
        action_path: "/events",
        pr_number: 1234,
        published: true
      )
      expect(feature.pro_tips_list).to eq([ "Tip A", "Tip B" ])
      expect(feature.rhino_description.to_plain_text).to include("Longer write-up")
    end

    it "matches an existing feature whose name differs only in case" do
      existing = create(:feature, name: "SEED FEATURE ONE")

      expect { catalog.import! }.to change(Feature, :count).by(1)
      expect(existing.reload.pr_number).to eq(1234)
    end

    it "does not overwrite admin-written content (summary)" do
      existing = create(:feature, name: "Seed feature one", summary: "Edited in-app")

      expect { catalog.import! }.to change(Feature, :count).by(1) # only "two" is new
      expect(existing.reload.summary).to eq("Edited in-app")
    end

    it "fills in blank content fields (missing info)" do
      existing = create(:feature, name: "Seed feature one", summary: "Edited in-app",
                                  external_url: nil)

      result = catalog.import!

      expect(result.updated).to eq(1)
      expect(existing.reload.external_url).to eq("https://docs.example.com/one")
      expect(existing.summary).to eq("Edited in-app") # admin content left alone
    end

    it "re-syncs catalog classification (audience/area/links) that has drifted from the seed" do
      existing = create(:feature, name: "Seed feature one",
                                  display_status: "admin_facing", area: "reporting",
                                  action_path: "/reports", pr_number: nil)

      result = catalog.import!

      expect(result.updated).to eq(1)
      expect(existing.reload).to have_attributes(
        display_status: "user_facing", # corrected back to the seed
        area: "events",
        action_path: "/events",
        pr_number: 1234
      )
    end

    it "leaves a feature edited in-app untouched, even blank fields and drifted classification" do
      existing = create(:feature, name: "Seed feature one", area: "reporting", external_url: nil,
                                  created_at: 2.days.ago, updated_at: 1.day.ago)

      result = catalog.import!

      expect(result.updated).to eq(0)
      expect(result.skipped).to eq(1)
      expect(existing.reload).to have_attributes(area: "reporting", external_url: nil)
    end

    it "does not count its own sync as an in-app edit" do
      existing = create(:feature, name: "Seed feature one", area: "reporting", external_url: nil,
                                  created_at: 2.days.ago, updated_at: 2.days.ago)

      catalog.import!

      expect(existing.reload).not_to be_edited
    end

    it "does not count a seeded description as an in-app edit" do
      catalog.import!

      expect(Feature.find_by(name: "Seed feature one")).not_to be_edited
    end

    it "is a no-op on a second run" do
      catalog.import!
      expect { catalog.import! }.not_to change(Feature, :count)
      expect(catalog.import!.any?).to be(false)
    end
  end

  describe "the checked-in seeds (db/seeds/features/)" do
    subject(:entries) { described_class.new.entries }

    it "is a non-empty list of one feature per file" do
      expect(entries).not_to be_empty
      expect(entries).to all(be_a(Hash))
    end

    it "has unique names" do
      names = entries.map { |entry| entry["name"].downcase }
      expect(names.tally.select { |_, count| count > 1 }.keys).to be_empty
    end

    it "has every required field with a valid area and audience" do
      entries.each do |entry|
        expect(entry["name"]).to be_present, "missing name: #{entry.inspect}"
        expect(entry["summary"]).to be_present, "missing summary for #{entry['name']}"
        expect(entry["released_on"]).to be_a(Date), "released_on must be a date for #{entry['name']}"
        expect(Feature::AREA_KEYS).to include(entry["area"]),
          "unknown area '#{entry['area']}' for #{entry['name']}"
        expect(Feature::DISPLAY_STATUS_KEYS).to include(entry["display_status"]),
          "unknown display_status '#{entry['display_status']}' for #{entry['name']}"
      end
    end

    it "produces valid Feature records when imported" do
      expect { described_class.new.import! }.not_to raise_error
      expect(Feature.all).to all(be_valid)
    end
  end
end
