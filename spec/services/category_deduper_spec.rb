# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryDeduper do
  subject(:service) { described_class.new(logger: logger, dry_run: dry_run, min_usage: min_usage) }

  let(:logger) { instance_double(Logger, info: nil) }
  let(:dry_run) { true }
  let(:min_usage) { 0 }

  describe "#call" do
    context "when there are no duplicate categories" do
      before do
        create(:category, name: "Unique Category 1")
        create(:category, name: "Unique Category 2")
      end

      it "completes without errors" do
        expect { service.call }.not_to raise_error
      end

      it "logs the start and completion" do
        service.call
        expect(logger).to have_received(:info).with("Starting category dedupe")
        expect(logger).to have_received(:info).with("Category dedupe complete")
      end
    end

    context "when there are duplicate categories with different case" do
      let!(:category1) { create(:category, name: "Test Category", published: true, created_at: 1.day.ago) }
      let!(:category2) { create(:category, name: "test category", published: false, created_at: Time.current) }
      let!(:workshop) { create(:workshop) }

      before do
        create(:categorizable_item, category: category1, categorizable: workshop)
      end

      it "logs the duplicate group" do
        service.call
        expect(logger).to have_received(:info).with("GROUP: 'test category'")
      end

      it "identifies the published category as primary" do
        service.call
        expect(logger).to have_received(:info).with(match(/KEEP.*#{category1.id}/))
      end

      it "identifies the unpublished category as duplicate" do
        service.call
        expect(logger).to have_received(:info).with(match(/MERGE.*#{category2.id}/))
      end

      context "when dry_run is false" do
        let(:dry_run) { false }

        it "removes the duplicate category" do
          expect { service.call }.to change { Category.count }.by(-1)
          expect(Category.exists?(category1.id)).to be true
          expect(Category.exists?(category2.id)).to be false
        end

        it "preserves the primary category" do
          service.call
          expect(Category.find(category1.id)).to eq(category1)
        end
      end

      context "when dry_run is true" do
        it "does not remove the duplicate category" do
          expect { service.call }.not_to change { Category.count }
        end
      end
    end

    context "when duplicate categories have different usage counts" do
      let!(:category_high_usage) { create(:category, name: "Popular", published: false, created_at: Time.current) }
      let!(:category_low_usage) { create(:category, name: "popular", published: false, created_at: 1.day.ago) }
      let!(:workshop1) { create(:workshop) }
      let!(:workshop2) { create(:workshop) }
      let!(:workshop3) { create(:workshop) }

      before do
        create(:categorizable_item, category: category_high_usage, categorizable: workshop1)
        create(:categorizable_item, category: category_high_usage, categorizable: workshop2)
        create(:categorizable_item, category: category_low_usage, categorizable: workshop3)
      end

      it "identifies the higher usage category as primary" do
        service.call
        expect(logger).to have_received(:info).with(match(/KEEP.*#{category_high_usage.id}.*usage=2/))
      end

      context "when dry_run is false" do
        let(:dry_run) { false }

        it "merges taggings to the primary category" do
          expect { service.call }.to change { CategorizableItem.where(category_id: category_high_usage.id).count }.from(2).to(3)
        end

        it "removes the duplicate category" do
          service.call
          expect(Category.exists?(category_low_usage.id)).to be false
        end
      end
    end

    context "when both duplicate categories have the same tagging" do
      let(:dry_run) { false }
      let!(:category1) { create(:category, name: "Shared", published: true) }
      let!(:category2) { create(:category, name: "shared", published: false) }
      let!(:workshop) { create(:workshop) }

      before do
        create(:categorizable_item, category: category1, categorizable: workshop)
        create(:categorizable_item, category: category2, categorizable: workshop)
      end

      it "removes duplicate taggings" do
        expect { service.call }.to change { CategorizableItem.count }.by(-1)
      end

      it "keeps only one tagging for the primary category" do
        service.call
        expect(CategorizableItem.where(category_id: category1.id, categorizable: workshop).count).to eq(1)
      end

      it "logs the deletion of duplicate tagging" do
        service.call
        expect(logger).to have_received(:info).with(match(/deleted duplicate tagging/))
      end
    end

    context "with min_usage threshold" do
      let(:min_usage) { 2 }
      let!(:category_used) { create(:category, name: "Used", published: true) }
      let!(:category_used_dupe) { create(:category, name: "used", published: false) }
      let!(:category_unused) { create(:category, name: "Unused", published: true) }
      let!(:category_unused_dupe) { create(:category, name: "unused", published: false) }

      before do
        create(:categorizable_item, category: category_used, categorizable: create(:workshop))
        create(:categorizable_item, category: category_used_dupe, categorizable: create(:workshop))
      end

      it "only processes groups with total usage above threshold" do
        service.call
        expect(logger).to have_received(:info).with("GROUP: 'used'")
        expect(logger).not_to have_received(:info).with("GROUP: 'unused'")
      end
    end

    context "when there are more than two duplicates" do
      let(:dry_run) { false }
      let!(:category1) { create(:category, name: "Multi", published: true, created_at: 3.days.ago) }
      let!(:category2) { create(:category, name: "multi", published: false, created_at: 2.days.ago) }
      let!(:category3) { create(:category, name: "MULTI", published: false, created_at: 1.day.ago) }

      it "merges all duplicates into one primary" do
        expect { service.call }.to change { Category.count }.by(-2)
        expect(Category.exists?(category1.id)).to be true
        expect(Category.exists?(category2.id)).to be false
        expect(Category.exists?(category3.id)).to be false
      end
    end
  end
end
