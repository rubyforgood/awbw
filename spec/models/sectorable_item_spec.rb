require 'rails_helper'

RSpec.describe SectorableItem do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:sector) }
    it { should belong_to(:sectorable) } # Polymorphic
  end

  describe 'validations' do
    subject { build(:sectorable_item) }
    it { should validate_presence_of(:sector_id) }
    it { should validate_uniqueness_of(:sector_id).scoped_to([ :sectorable_type, :sectorable_id ]).with_message("has already been added") }
  end

  describe "#title" do
    it "reads as the sector for a sectorable with no title of its own" do
      tagging = create(:sectorable_item, sectorable: create(:organization), sector: create(:sector, name: "Housing"))

      expect(tagging.title).to eq("Housing")
    end

    it "composes the log's title and windows type for a workshop log" do
      log = create(:workshop_log)
      tagging = create(:sectorable_item, sectorable: log)

      expect(tagging.title).to start_with(log.title.to_s)
    end

    it "does not raise for a non-WorkshopLog sectorable (e.g. a person)" do
      item = create(:person).sectorable_items.create!(sector: create(:sector, :published))

      expect { item.title }.not_to raise_error
    end
  end

  describe "lifecycle tracking" do
    # Regression: SectorableItem#title referenced windows_type (a WorkshopLog-only
    # association), so building the Ahoy payload raised for a person/org sector tag
    # and the event was silently swallowed — sector tag changes went untracked.
    it "buffers a create.sectorable_item event when a person is tagged with a sector" do
      person = create(:person)
      Current.source = "public_registration"
      allow(Analytics::LifecycleBuffer).to receive(:push).and_call_original

      person.sectorable_items.create!(sector: create(:sector, :published))

      expect(Analytics::LifecycleBuffer).to have_received(:push)
        .with(hash_including(name: "create.sectorable_item"))
    ensure
      Current.source = nil
    end
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:sectorable_item)).to be_valid
  #   pending("Requires functional sector/sectorable factories and associations uncommented")
  # end
end
