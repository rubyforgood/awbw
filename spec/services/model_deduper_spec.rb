# frozen_string_literal: true

require "rails_helper"

RSpec.describe ModelDeduper do
  let(:logger) { instance_double(Logger, info: nil) }
  let(:dry_run) { true }
  let(:min_usage) { 0 }

  shared_examples "a model deduper" do |model_class:, join_class:, join_factory:, join_fk:|
    subject(:service) do
      described_class.new(model_class: model_class, logger: logger, dry_run: dry_run, min_usage: min_usage)
    end

    let(:model_label) { model_class.name.underscore.humanize.downcase }
    let(:factory_name) { model_class.name.underscore.to_sym }

    # Helper to create duplicate records that bypass uniqueness validation
    def create_record(model_class, name:, **attrs)
      record = build(model_class.name.underscore.to_sym, name: name, **attrs)
      record.save!(validate: false)
      record
    end

    describe "#call" do
      context "when there are no duplicates" do
        before do
          create(factory_name, name: "Unique 1")
          create(factory_name, name: "Unique 2")
        end

        it "completes without errors" do
          expect { service.call }.not_to raise_error
        end

        it "logs the start and completion" do
          service.call
          expect(logger).to have_received(:info).with("Starting #{model_label} dedupe")
          expect(logger).to have_received(:info).with("#{model_label.capitalize} dedupe complete")
        end
      end

      context "when there are duplicates with different case" do
        let!(:record1) { create_record(model_class, name: "Test Record", published: true, created_at: 1.day.ago) }
        let!(:record2) { create_record(model_class, name: "test record", published: false, created_at: Time.current) }
        let!(:workshop) { create(:workshop) }

        before do
          create(join_factory, join_fk => record1.id, :categorizable => workshop) if join_class == CategorizableItem
          create(join_factory, join_fk => record1.id, :sectorable => workshop) if join_class == SectorableItem
        end

        it "logs the duplicate group" do
          service.call
          expect(logger).to have_received(:info).with("GROUP: 'test record'")
        end

        it "identifies the published record as primary" do
          service.call
          expect(logger).to have_received(:info).with(match(/KEEP.*#{record1.id}/))
        end

        it "identifies the unpublished record as duplicate" do
          service.call
          expect(logger).to have_received(:info).with(match(/MERGE.*#{record2.id}/))
        end

        context "when dry_run is false" do
          let(:dry_run) { false }

          it "removes the duplicate" do
            expect { service.call }.to change { model_class.count }.by(-1)
            expect(model_class.exists?(record1.id)).to be true
            expect(model_class.exists?(record2.id)).to be false
          end

          it "preserves the primary" do
            service.call
            expect(model_class.find(record1.id)).to eq(record1)
          end
        end

        context "when dry_run is true" do
          it "does not remove the duplicate" do
            expect { service.call }.not_to change { model_class.count }
          end
        end
      end

      context "when duplicates have different usage counts" do
        let!(:high_usage) { create_record(model_class, name: "Popular", published: false, created_at: Time.current) }
        let!(:low_usage) { create_record(model_class, name: "popular", published: false, created_at: 1.day.ago) }
        let!(:workshop1) { create(:workshop) }
        let!(:workshop2) { create(:workshop) }
        let!(:workshop3) { create(:workshop) }

        before do
          if join_class == CategorizableItem
            create(join_factory, category: high_usage, categorizable: workshop1)
            create(join_factory, category: high_usage, categorizable: workshop2)
            create(join_factory, category: low_usage, categorizable: workshop3)
          elsif join_class == SectorableItem
            create(join_factory, sector: high_usage, sectorable: workshop1)
            create(join_factory, sector: high_usage, sectorable: workshop2)
            create(join_factory, sector: low_usage, sectorable: workshop3)
          end
        end

        it "identifies the higher usage record as primary" do
          service.call
          expect(logger).to have_received(:info).with(match(/KEEP.*#{high_usage.id}.*usage=2/))
        end

        context "when dry_run is false" do
          let(:dry_run) { false }

          it "merges taggings to the primary" do
            expect { service.call }.to change { join_class.where(join_fk => high_usage.id).count }.from(2).to(3)
          end

          it "removes the duplicate" do
            service.call
            expect(model_class.exists?(low_usage.id)).to be false
          end
        end
      end

      context "when both duplicates have the same tagging" do
        let(:dry_run) { false }
        let!(:record1) { create_record(model_class, name: "Shared", published: true) }
        let!(:record2) { create_record(model_class, name: "shared", published: false) }
        let!(:workshop) { create(:workshop) }

        before do
          if join_class == CategorizableItem
            create(join_factory, category: record1, categorizable: workshop)
            create(join_factory, category: record2, categorizable: workshop)
          elsif join_class == SectorableItem
            create(join_factory, sector: record1, sectorable: workshop)
            create(join_factory, sector: record2, sectorable: workshop)
          end
        end

        it "removes duplicate taggings" do
          expect { service.call }.to change { join_class.count }.by(-1)
        end

        it "keeps only one tagging for the primary" do
          service.call
          expect(join_class.where(join_fk => record1.id).count).to eq(1)
        end

        it "logs the deletion of duplicate tagging" do
          service.call
          expect(logger).to have_received(:info).with(match(/deleted duplicate/))
        end
      end

      context "with min_usage threshold" do
        let(:min_usage) { 2 }
        let!(:used) { create_record(model_class, name: "Used", published: true) }
        let!(:used_dupe) { create_record(model_class, name: "used", published: false) }
        let!(:unused) { create_record(model_class, name: "Unused", published: true) }
        let!(:unused_dupe) { create_record(model_class, name: "unused", published: false) }

        before do
          if join_class == CategorizableItem
            create(join_factory, category: used, categorizable: create(:workshop))
            create(join_factory, category: used_dupe, categorizable: create(:workshop))
          elsif join_class == SectorableItem
            create(join_factory, sector: used, sectorable: create(:workshop))
            create(join_factory, sector: used_dupe, sectorable: create(:workshop))
          end
        end

        it "only processes groups with total usage above threshold" do
          service.call
          expect(logger).to have_received(:info).with("GROUP: 'used'")
          expect(logger).not_to have_received(:info).with("GROUP: 'unused'")
        end
      end

      context "when there are more than two duplicates" do
        let(:dry_run) { false }
        let!(:record1) { create_record(model_class, name: "Multi", published: true, created_at: 3.days.ago) }
        let!(:record2) { create_record(model_class, name: "multi", published: false, created_at: 2.days.ago) }
        let!(:record3) { create_record(model_class, name: "MULTI", published: false, created_at: 1.day.ago) }

        it "merges all duplicates into one primary" do
          expect { service.call }.to change { model_class.count }.by(-2)
          expect(model_class.exists?(record1.id)).to be true
          expect(model_class.exists?(record2.id)).to be false
          expect(model_class.exists?(record3.id)).to be false
        end
      end
    end
  end

  context "with Category" do
    include_examples "a model deduper",
      model_class: Category,
      join_class: CategorizableItem,
      join_factory: :categorizable_item,
      join_fk: :category_id
  end

  context "with Sector" do
    include_examples "a model deduper",
      model_class: Sector,
      join_class: SectorableItem,
      join_factory: :sectorable_item,
      join_fk: :sector_id
  end
end
