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
    end

    describe "#merge" do
      let(:dry_run) { false }
      let!(:record_to_keep) { create(factory_name, name: "Keep This", published: true) }
      let!(:record_to_delete) { create(factory_name, name: "Delete This", published: false) }
      let!(:workshop) { create(:workshop) }

      before do
        if join_class == CategorizableItem
          create(join_factory, category: record_to_delete, categorizable: workshop)
        elsif join_class == SectorableItem
          create(join_factory, sector: record_to_delete, sectorable: workshop)
        end
      end

      it "moves taggings to the kept record" do
        service.merge(record_to_keep, record_to_delete)
        expect(join_class.where(join_fk => record_to_keep.id).count).to eq(1)
        expect(join_class.where(join_fk => record_to_delete.id).count).to eq(0)
      end

      it "deletes the duplicate record" do
        expect { service.merge(record_to_keep, record_to_delete) }
          .to change { model_class.count }.by(-1)
        expect(model_class.exists?(record_to_keep.id)).to be true
        expect(model_class.exists?(record_to_delete.id)).to be false
      end

      context "when both records have a tagging for the same workshop" do
        before do
          if join_class == CategorizableItem
            create(join_factory, category: record_to_keep, categorizable: workshop)
          elsif join_class == SectorableItem
            create(join_factory, sector: record_to_keep, sectorable: workshop)
          end
        end

        it "removes the duplicate tagging" do
          expect { service.merge(record_to_keep, record_to_delete) }
            .to change { join_class.count }.by(-1)
        end

        it "keeps only one tagging for the kept record" do
          service.merge(record_to_keep, record_to_delete)
          expect(join_class.where(join_fk => record_to_keep.id).count).to eq(1)
        end

        it "logs the deletion of duplicate tagging" do
          service.merge(record_to_keep, record_to_delete)
          expect(logger).to have_received(:info).with(match(/deleted duplicate/))
        end
      end
    end

    describe "uniqueness enforcement" do
      it "prevents creating a duplicate name at the database level" do
        create(factory_name, name: "Original")
        duplicate = build(factory_name, name: "Original")
        expect(duplicate).not_to be_valid
      end

      it "prevents case-insensitive duplicates" do
        create(factory_name, name: "Test Name")
        duplicate = build(factory_name, name: "test name")
        expect(duplicate).not_to be_valid
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
