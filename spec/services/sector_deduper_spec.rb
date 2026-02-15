# frozen_string_literal: true

require "rails_helper"

RSpec.describe SectorDeduper do
  subject(:service) { described_class.new(logger: logger, dry_run: dry_run, min_usage: min_usage) }

  let(:logger) { instance_double(Logger, info: nil) }
  let(:dry_run) { true }
  let(:min_usage) { 0 }

  # Helper to create duplicate sectors that bypass uniqueness validation
  def create_sector(name:, **attrs)
    s = build(:sector, name: name, **attrs)
    s.save!(validate: false)
    s
  end

  describe "#call" do
    context "when there are no duplicate sectors" do
      before do
        create(:sector, name: "Unique Sector 1")
        create(:sector, name: "Unique Sector 2")
      end

      it "completes without errors" do
        expect { service.call }.not_to raise_error
      end

      it "logs the start and completion" do
        service.call
        expect(logger).to have_received(:info).with("Starting sector dedupe")
        expect(logger).to have_received(:info).with("Sector dedupe complete")
      end
    end

    context "when there are duplicate sectors with different case" do
      let!(:sector1) { create_sector(name: "Test Sector", published: true, created_at: 1.day.ago) }
      let!(:sector2) { create_sector(name: "test sector", published: false, created_at: Time.current) }
      let!(:workshop) { create(:workshop) }

      before do
        create(:sectorable_item, sector: sector1, sectorable: workshop)
      end

      it "logs the duplicate group" do
        service.call
        expect(logger).to have_received(:info).with("GROUP: 'test sector'")
      end

      it "identifies the published sector as primary" do
        service.call
        expect(logger).to have_received(:info).with(match(/KEEP.*#{sector1.id}/))
      end

      it "identifies the unpublished sector as duplicate" do
        service.call
        expect(logger).to have_received(:info).with(match(/MERGE.*#{sector2.id}/))
      end

      context "when dry_run is false" do
        let(:dry_run) { false }

        it "removes the duplicate sector" do
          expect { service.call }.to change { Sector.count }.by(-1)
          expect(Sector.exists?(sector1.id)).to be true
          expect(Sector.exists?(sector2.id)).to be false
        end

        it "preserves the primary sector" do
          service.call
          expect(Sector.find(sector1.id)).to eq(sector1)
        end
      end

      context "when dry_run is true" do
        it "does not remove the duplicate sector" do
          expect { service.call }.not_to change { Sector.count }
        end
      end
    end

    context "when duplicate sectors have different usage counts" do
      let!(:sector_high_usage) { create_sector(name: "Popular", published: false, created_at: Time.current) }
      let!(:sector_low_usage) { create_sector(name: "popular", published: false, created_at: 1.day.ago) }
      let!(:workshop1) { create(:workshop) }
      let!(:workshop2) { create(:workshop) }
      let!(:workshop3) { create(:workshop) }

      before do
        create(:sectorable_item, sector: sector_high_usage, sectorable: workshop1)
        create(:sectorable_item, sector: sector_high_usage, sectorable: workshop2)
        create(:sectorable_item, sector: sector_low_usage, sectorable: workshop3)
      end

      it "identifies the higher usage sector as primary" do
        service.call
        expect(logger).to have_received(:info).with(match(/KEEP.*#{sector_high_usage.id}.*usage=2/))
      end

      context "when dry_run is false" do
        let(:dry_run) { false }

        it "merges taggings to the primary sector" do
          expect { service.call }.to change { SectorableItem.where(sector_id: sector_high_usage.id).count }.from(2).to(3)
        end

        it "removes the duplicate sector" do
          service.call
          expect(Sector.exists?(sector_low_usage.id)).to be false
        end
      end
    end

    context "when both duplicate sectors have the same tagging" do
      let(:dry_run) { false }
      let!(:sector1) { create_sector(name: "Shared", published: true) }
      let!(:sector2) { create_sector(name: "shared", published: false) }
      let!(:workshop) { create(:workshop) }

      before do
        create(:sectorable_item, sector: sector1, sectorable: workshop)
        create(:sectorable_item, sector: sector2, sectorable: workshop)
      end

      it "removes duplicate taggings" do
        expect { service.call }.to change { SectorableItem.count }.by(-1)
      end

      it "keeps only one tagging for the primary sector" do
        service.call
        expect(SectorableItem.where(sector_id: sector1.id, sectorable: workshop).count).to eq(1)
      end

      it "logs the deletion of duplicate tagging" do
        service.call
        expect(logger).to have_received(:info).with(match(/deleted duplicate tagging/))
      end
    end

    context "with min_usage threshold" do
      let(:min_usage) { 2 }
      let!(:sector_used) { create_sector(name: "Used", published: true) }
      let!(:sector_used_dupe) { create_sector(name: "used", published: false) }
      let!(:sector_unused) { create_sector(name: "Unused", published: true) }
      let!(:sector_unused_dupe) { create_sector(name: "unused", published: false) }

      before do
        create(:sectorable_item, sector: sector_used, sectorable: create(:workshop))
        create(:sectorable_item, sector: sector_used_dupe, sectorable: create(:workshop))
      end

      it "only processes groups with total usage above threshold" do
        service.call
        expect(logger).to have_received(:info).with("GROUP: 'used'")
        expect(logger).not_to have_received(:info).with("GROUP: 'unused'")
      end
    end

    context "when there are more than two duplicates" do
      let(:dry_run) { false }
      let!(:sector1) { create_sector(name: "Multi", published: true, created_at: 3.days.ago) }
      let!(:sector2) { create_sector(name: "multi", published: false, created_at: 2.days.ago) }
      let!(:sector3) { create_sector(name: "MULTI", published: false, created_at: 1.day.ago) }

      it "merges all duplicates into one primary" do
        expect { service.call }.to change { Sector.count }.by(-2)
        expect(Sector.exists?(sector1.id)).to be true
        expect(Sector.exists?(sector2.id)).to be false
        expect(Sector.exists?(sector3.id)).to be false
      end
    end
  end
end
