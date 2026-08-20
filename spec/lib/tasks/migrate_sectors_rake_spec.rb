require "rails_helper"
require "rake"

# These specs exist to prove the data migration is SAFE to run against live data:
# it must never silently drop sectors or their taggings, must be a no-op in
# dry-run, must leave unrelated data alone, and must be safe to re-run.
RSpec.describe "data:migrate_sectors" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("data:migrate_sectors")
  end

  around do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
  ensure
    $stdout = original_stdout
  end

  def invoke_task
    Rake::Task["data:migrate_sectors"].reenable
    Rake::Task["data:migrate_sectors"].invoke
  end

  def with_env(key, value)
    previous = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = previous
  end

  # Tag a sector against a polymorphic taggable (default: a fresh workshop).
  def tag(sector, taggable = create(:workshop))
    create(:sectorable_item, sector: sector, sectorable: taggable)
  end

  describe "dry run (default)" do
    let!(:legacy) { create(:sector, name: "Child abuse", published: false) }
    let!(:canonical) { create(:sector, :published, name: "Child Abuse/Neglect") }
    let!(:tagging) { tag(legacy) }

    it "does not create, rename, or destroy any sectors" do
      with_env("DRY_RUN", nil) { invoke_task }

      expect(Sector.pluck(:name)).to contain_exactly("Child abuse", "Child Abuse/Neglect")
      expect(legacy.reload.name).to eq("Child abuse")
    end

    it "does not move or delete any taggings" do
      with_env("DRY_RUN", nil) { invoke_task }

      expect(tagging.reload.sector_id).to eq(legacy.id)
      expect(SectorableItem.count).to eq(1)
    end
  end

  describe "execute (DRY_RUN=false)" do
    describe "merge when the canonical target already exists" do
      let!(:legacy) { create(:sector, name: "Child abuse", published: false) }
      let!(:canonical) { create(:sector, :published, name: "Child Abuse/Neglect") }

      it "moves the legacy taggings onto the canonical sector and destroys the legacy record" do
        tagging = tag(legacy)

        with_env("DRY_RUN", "false") { invoke_task }

        expect(Sector.exists?(legacy.id)).to be(false)
        expect(tagging.reload.sector_id).to eq(canonical.id)
      end

      it "collapses a duplicate tagging when the same item is tagged on both sectors" do
        workshop = create(:workshop)
        tag(legacy, workshop)
        tag(canonical, workshop)

        expect { with_env("DRY_RUN", "false") { invoke_task } }
          .to change(SectorableItem, :count).from(2).to(1)

        expect(canonical.reload.sectorable_items.count).to eq(1)
      end

      it "never leaves a tagging pointing at a destroyed sector" do
        tag(legacy)

        with_env("DRY_RUN", "false") { invoke_task }

        expect(SectorableItem.where(sector_id: legacy.id)).to be_empty
        expect(SectorableItem.where.not(sector_id: Sector.select(:id))).to be_empty
      end
    end

    describe "rename when the target does not yet exist" do
      let!(:legacy) { create(:sector, :published, name: "Disability") }

      it "renames the record in place, preserves taggings, and creates no duplicate" do
        tagging = tag(legacy)

        with_env("DRY_RUN", "false") { invoke_task }

        # Same record id, renamed — not destroyed-and-recreated.
        expect(legacy.reload.name).to eq("Disability Services")
        expect(Sector.where(name: "Disability")).to be_empty
        expect(Sector.where(name: "Disability Services").pluck(:id)).to eq([ legacy.id ])
        expect(tagging.reload.sector_id).to eq(legacy.id)
      end
    end

    describe "brand-new tags" do
      it "creates Community Engagement as a published sector" do
        with_env("DRY_RUN", "false") { invoke_task }

        sector = Sector.find_by(name: "Community Engagement")
        expect(sector).to be_present
        expect(sector).to be_published
      end
    end

    describe "chained merges" do
      it "folds a multi-step chain onto the final canonical name, carrying taggings" do
        # Ops 44–45: "Substance use" -> "Substance Abuse" -> "Substance Use/Recovery".
        # Only the first legacy record exists, so the chain renames it forward.
        source = create(:sector, :published, name: "Substance use")
        tagging = tag(source)

        with_env("DRY_RUN", "false") { invoke_task }

        expect(Sector.where(name: [ "Substance use", "Substance Abuse" ])).to be_empty
        final = Sector.find_by(name: "Substance Use/Recovery")
        expect(final).to be_present
        expect(tagging.reload.sector_id).to eq(final.id)
      end
    end

    describe "spreadsheet typo correction" do
      it "lands 'Advocacy' on the correctly spelled 'Systems/Policy Change'" do
        advocacy = create(:sector, :published, name: "Advocacy")
        tagging = tag(advocacy)

        with_env("DRY_RUN", "false") { invoke_task }

        expect(Sector.find_by(name: "Sytems/Policy Change")).to be_nil
        canonical = Sector.find_by(name: "Systems/Policy Change")
        expect(canonical).to be_present
        expect(tagging.reload.sector_id).to eq(canonical.id)
      end
    end

    describe "sectors not named in the mapping" do
      it "leaves an unrelated sector and its taggings completely untouched" do
        unrelated = create(:sector, :published, name: "Totally Unrelated Sector")
        tagging = tag(unrelated)

        with_env("DRY_RUN", "false") { invoke_task }

        expect(unrelated.reload.name).to eq("Totally Unrelated Sector")
        expect(tagging.reload.sector_id).to eq(unrelated.id)
      end
    end

    describe "missing legacy sources" do
      it "skips absent sources without error and creates only the ADD tags" do
        # No legacy records at all: every rename/merge is a no-op, only the
        # brand-new / canonical tags get created.
        expect { with_env("DRY_RUN", "false") { invoke_task } }.not_to raise_error

        expect(Sector.find_by(name: "Community Engagement")).to be_present
        expect(Sector.find_by(name: "Self-Care/Personal Growth")).to be_present
      end
    end

    describe "idempotency" do
      it "is safe to run twice and produces no further changes on the second run" do
        legacy = create(:sector, name: "Child abuse", published: false)
        canonical = create(:sector, :published, name: "Child Abuse/Neglect")
        tag(legacy)

        with_env("DRY_RUN", "false") { invoke_task }
        snapshot = { sectors: Sector.order(:name).pluck(:name), taggings: SectorableItem.count }

        expect { with_env("DRY_RUN", "false") { invoke_task } }
          .not_to change(SectorableItem, :count)
        expect(Sector.order(:name).pluck(:name)).to eq(snapshot[:sectors])
        expect(SectorableItem.count).to eq(snapshot[:taggings])
        expect(canonical.reload.sectorable_items.count).to eq(1)
      end
    end

    describe "no tagging is lost across a full run" do
      it "preserves every tagging except intentional duplicate collapses" do
        # Two legacy sources merging into one canonical, each tagged with a
        # distinct workshop -> both taggings survive on the canonical record.
        canonical = create(:sector, :published, name: "Education")
        student_services = create(:sector, name: "Student Services", published: false)
        tag(student_services)
        tag(canonical)

        expect { with_env("DRY_RUN", "false") { invoke_task } }
          .not_to change(SectorableItem, :count)

        expect(Sector.find_by(name: "Education").sectorable_items.count).to eq(2)
        expect(Sector.exists?(student_services.id)).to be(false)
      end
    end
  end
end
