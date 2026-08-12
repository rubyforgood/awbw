require "rails_helper"

RSpec.describe FeatureCatalog do
  describe "#import!" do
    let(:seed_path) { Rails.root.join("spec/fixtures/files/features_seed.yml") }

    before do
      File.write(seed_path, <<~YAML)
        - name: "Seed feature one"
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
        - name: "Seed feature two"
          area: scholarships
          display_status: admin_facing
          summary: "Second seeded feature."
          released_on: 2026-08-05
      YAML
    end

    after { File.delete(seed_path) if File.exist?(seed_path) }

    subject(:catalog) { described_class.new(path: seed_path) }

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

    it "does not overwrite a field an admin already filled in" do
      existing = create(:feature, name: "Seed feature one", summary: "Edited in-app")

      expect { catalog.import! }.to change(Feature, :count).by(1) # only "two" is new
      expect(existing.reload.summary).to eq("Edited in-app")
    end

    it "fills in blank fields on an existing feature (missing info)" do
      existing = create(:feature, name: "Seed feature one", summary: "Edited in-app",
                                  action_path: nil, pr_number: nil, external_url: nil)

      result = catalog.import!

      expect(result.updated).to eq(1)
      expect(existing.reload).to have_attributes(
        action_path: "/events",
        pr_number: 1234,
        external_url: "https://docs.example.com/one"
      )
      expect(existing.summary).to eq("Edited in-app") # non-blank field left alone
    end

    it "is a no-op on a second run" do
      catalog.import!
      expect { catalog.import! }.not_to change(Feature, :count)
      expect(catalog.import!.any?).to be(false)
    end
  end

  describe "the checked-in seed (config/features.yml)" do
    subject(:entries) { described_class.new.entries }

    it "is a non-empty list" do
      expect(entries).to be_an(Array)
      expect(entries).not_to be_empty
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
