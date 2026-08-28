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

  # Organizations are referenced by plain organization_id foreign keys rather than
  # polymorphic joins, so they exercise the reflection-driven FK reassignment pass.
  describe "foreign-key reassignment (Organization)" do
    subject(:service) do
      described_class.new(model_class: Organization, logger: logger, dry_run: false)
    end

    let!(:keep) { create(:organization, name: "Keep Org") }
    let!(:dupe) { create(:organization, name: "Dupe Org") }

    it "reassigns plain FK associations to the kept organization" do
      report = create(:report, organization: dupe)
      service.merge(keep, dupe)
      expect(report.reload.organization_id).to eq(keep.id)
    end

    it "reassigns restrict_with_error associations and still deletes the duplicate" do
      affiliation = create(:affiliation, organization: dupe)

      expect { service.merge(keep, dupe) }
        .to change { Organization.exists?(dupe.id) }.from(true).to(false)
      expect(affiliation.reload.organization_id).to eq(keep.id)
    end

    it "moves a non-colliding event registration link to the kept organization" do
      registration = create(:event_registration)
      link = create(:event_registration_organization, organization: dupe, event_registration: registration)

      service.merge(keep, dupe)
      expect(link.reload.organization_id).to eq(keep.id)
    end

    it "collapses a natural-key collision instead of violating the unique index" do
      registration = create(:event_registration)
      create(:event_registration_organization, organization: keep, event_registration: registration)
      colliding = create(:event_registration_organization, organization: dupe, event_registration: registration)

      expect { service.merge(keep, dupe) }
        .to change(EventRegistrationOrganization, :count).by(-1)
      expect(EventRegistrationOrganization.exists?(colliding.id)).to be false
      expect(EventRegistrationOrganization.where(organization_id: keep.id, event_registration_id: registration.id).count).to eq(1)
    end

    it "reassigns polymorphic joins alongside FK associations" do
      bookmark = create(:bookmark, bookmarkable: dupe)
      service.merge(keep, dupe)
      expect(bookmark.reload.bookmarkable).to eq(keep)
    end

    # Payment/Story reference organizations by FK but Organization declares no
    # inverse has_many, so they are only reachable via the belongs_to scan. Their
    # DB foreign keys would otherwise block the destroy.
    it "reassigns FK children that have no inverse has_many on the model" do
      news = create(:community_news, organization: dupe)
      story = create(:story, organization: dupe)

      expect { service.merge(keep, dupe) }.not_to raise_error
      expect(news.reload.organization_id).to eq(keep.id)
      expect(story.reload.organization_id).to eq(keep.id)
    end
  end

  describe "#unhandled_references (coverage safeguard)" do
    subject(:service) { described_class.new(model_class: Organization) }

    let(:org) { create(:organization, name: "Solo Org") }

    it "is empty when every reference is reassignable" do
      create(:affiliation, organization: org)
      create(:report, organization: org)

      expect(service.unhandled_references(org)).to eq([])
    end

    it "flags a polymorphic reference the deduper does not reassign" do
      # OtherResponse#owner is covered, but #promotable is not — a promotable
      # pointing at the org would be orphaned on merge.
      create(:other_response, promotable: org)

      expect(service.unhandled_references(org))
        .to include(a_hash_including(table: "other_responses", column: "promotable_id"))
    end

    it "ignores gem-managed infrastructure that references the org" do
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename: "logo.png", byte_size: 1, checksum: "x", content_type: "image/png"
      )
      ActiveStorage::Attachment.create!(name: "logo", record: org, blob: blob)

      tables = service.unhandled_references(org).map { |ref| ref[:table] }
      expect(tables).not_to include("active_storage_attachments")
    end
  end

  describe "analytics/audit reassignment" do
    subject(:service) { described_class.new(model_class: Organization, logger: logger, dry_run: false) }

    let!(:keep) { create(:organization, name: "Keep Org") }
    let!(:dupe) { create(:organization, name: "Dupe Org") }
    let(:ahoy_events) { Class.new(ActiveRecord::Base) { self.table_name = "ahoy_events" } }
    let(:versions) { Class.new(ActiveRecord::Base) { self.table_name = "versions" } }

    it "repoints ahoy events to the kept organization" do
      event = ahoy_events.create!(name: "view", resource_type: "Organization", resource_id: dupe.id, time: Time.current)

      service.merge(keep, dupe)
      expect(event.reload.resource_id).to eq(keep.id)
    end

    it "repoints paper_trail versions to the kept organization" do
      version = versions.create!(event: "update", item_type: "Organization", item_id: dupe.id)

      service.merge(keep, dupe)
      expect(version.reload.item_id).to eq(keep.id)
    end
  end

  describe "#lost_references" do
    subject(:service) { described_class.new(model_class: Organization) }

    it "reports attached files that are deleted with the record" do
      org = create(:organization)
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename: "logo.png", byte_size: 1, checksum: "x", content_type: "image/png"
      )
      ActiveStorage::Attachment.create!(name: "logo", record: org, blob: blob)

      expect(service.lost_references(org)).to include(a_hash_including(count: 1))
    end

    it "is empty when the record has no attached files" do
      expect(service.lost_references(create(:organization))).to eq([])
    end
  end
end
