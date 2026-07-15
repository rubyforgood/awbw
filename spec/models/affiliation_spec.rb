require "rails_helper"

RSpec.describe Affiliation, type: :model do
  describe "comments" do
    it "holds comments as the polymorphic commentable" do
      affiliation = create(:affiliation)
      comment = affiliation.comments.create!(body: "A note about this affiliation")

      expect(comment.commentable).to eq(affiliation)
    end
  end

  describe "lifecycle tracking" do
    it "buffers an update.affiliation ahoy event when edited by a user" do
      affiliation = create(:affiliation, title: "Facilitator")
      Current.user = create(:user, :admin)
      allow(Analytics::LifecycleBuffer).to receive(:push).and_call_original

      affiliation.update!(title: "Lead facilitator")

      expect(Analytics::LifecycleBuffer).to have_received(:push)
        .with(hash_including(name: "update.affiliation"))
    end
  end

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:person) }
    it { should belong_to(:organization_address).class_name("Address").optional }
  end

  describe 'validations' do
    subject do
      build(:affiliation, organization: create(:organization), person: create(:person))
    end
    it { should validate_presence_of(:organization_id) }
    # it { should validate_presence_of(:person_id) } # we needed to not have this to support nested attrs
  end

  describe '#organization_address' do
    let(:organization) { create(:organization) }
    let(:address) { create(:address, addressable: organization) }

    it 'is valid when the address belongs to the same organization' do
      affiliation = build(:affiliation, organization: organization, organization_address: address)
      expect(affiliation).to be_valid
    end

    it 'is valid when no address is linked' do
      affiliation = build(:affiliation, organization: organization, organization_address: nil)
      expect(affiliation).to be_valid
    end

    it 'is invalid when the address belongs to a different organization' do
      other_address = create(:address, addressable: create(:organization))
      affiliation = build(:affiliation, organization: organization, organization_address: other_address)
      expect(affiliation).not_to be_valid
      expect(affiliation.errors[:organization_address_id]).to be_present
    end

    it "is invalid when the address belongs to a person" do
      person_address = create(:address, addressable: create(:person))
      affiliation = build(:affiliation, organization: organization, organization_address: person_address)
      expect(affiliation).not_to be_valid
    end

    it 'is nullified when its linked address is destroyed' do
      affiliation = create(:affiliation, organization: organization, organization_address: address)
      address.destroy
      expect(affiliation.reload.organization_address_id).to be_nil
    end
  end

  describe '#active?' do
    it 'is true when not inactive and has no end date' do
      expect(build(:affiliation, inactive: false, end_date: nil).active?).to be true
    end

    it 'is true when not inactive and the end date is in the future' do
      expect(build(:affiliation, inactive: false, end_date: 1.month.from_now).active?).to be true
    end

    it 'is false when flagged inactive' do
      expect(build(:affiliation, inactive: true, end_date: nil).active?).to be false
    end

    it 'is false when the end date has passed' do
      expect(build(:affiliation, inactive: false, end_date: 1.day.ago).active?).to be false
    end
  end

  describe '.active' do
    let!(:active_op) { create(:affiliation, inactive: false, end_date: nil) }
    let!(:active_with_future_end) { create(:affiliation, inactive: false, end_date: 1.month.from_now) }
    let!(:inactive_by_flag) { create(:affiliation, inactive: true, end_date: nil) }
    let!(:inactive_by_end_date) { create(:affiliation, inactive: false, end_date: 1.day.ago) }

    it 'includes records with inactive: false and no end date' do
      expect(described_class.active).to include(active_op)
    end

    it 'includes records with inactive: false and future end date' do
      expect(described_class.active).to include(active_with_future_end)
    end

    it 'excludes records with inactive: true' do
      expect(described_class.active).not_to include(inactive_by_flag)
    end

    it 'excludes records with past end date' do
      expect(described_class.active).not_to include(inactive_by_end_date)
    end

    it 'qualifies end_date when joined with organizations (which also has end_date)' do
      expect {
        described_class.active.joins(:organization).to_a
      }.not_to raise_error
    end
  end

  describe '#facilitator?' do
    it 'is true for the exact title "Facilitator"' do
      expect(build(:affiliation, title: "Facilitator").facilitator?).to be true
    end

    it 'ignores surrounding whitespace' do
      expect(build(:affiliation, title: "  Facilitator ").facilitator?).to be true
    end

    it 'is false for title variants like "Lead Facilitator"' do
      expect(build(:affiliation, title: "Lead Facilitator").facilitator?).to be false
    end

    it 'is case-sensitive' do
      expect(build(:affiliation, title: "facilitator").facilitator?).to be false
      expect(build(:affiliation, title: "FACILITATOR").facilitator?).to be false
    end

    it 'is false when the title is blank' do
      expect(build(:affiliation, title: nil).facilitator?).to be false
    end
  end

  describe '.facilitators' do
    let!(:exact) { create(:affiliation, title: "Facilitator") }
    let!(:whitespace) { create(:affiliation, title: "  Facilitator ") }
    let!(:variant) { create(:affiliation, title: "Lead Facilitator") }
    let!(:lowercase) { create(:affiliation, title: "facilitator") }

    it 'includes only the exact, case-sensitive title "Facilitator" (whitespace-trimmed)' do
      expect(described_class.facilitators).to contain_exactly(exact, whitespace)
    end
  end

  describe '#sync_organization_status_with_affiliations' do
    let!(:active_status) { OrganizationStatus.find_or_create_by!(name: "Active") }
    let!(:formerly_active_status) { OrganizationStatus.find_or_create_by!(name: "Formerly active") }

    it 'sets the organization to Formerly active when its last active affiliation goes inactive' do
      org = create(:organization, organization_status: active_status)
      affiliation = create(:affiliation, organization: org, inactive: false, end_date: nil)

      affiliation.update!(inactive: true)

      expect(org.reload.organization_status).to eq(formerly_active_status)
    end

    it 'sets a Formerly active organization back to Active when it regains an active affiliation' do
      org = create(:organization, organization_status: formerly_active_status)

      create(:affiliation, organization: org, inactive: false, end_date: nil)

      expect(org.reload.organization_status).to eq(active_status)
    end

    it 'ignores non-facilitator affiliations when deciding status' do
      org = create(:organization, organization_status: active_status)
      create(:affiliation, organization: org, title: "Volunteer", inactive: false, end_date: nil)

      expect(org.reload.organization_status).to eq(formerly_active_status)
    end

    it "leaves an Unknown organization untouched when it regains an active affiliation" do
      status = OrganizationStatus.find_or_create_by!(name: "Unknown")
      org = create(:organization, organization_status: status)

      create(:affiliation, organization: org, inactive: false, end_date: nil)

      expect(org.reload.organization_status).to eq(status)
    end
  end

  describe '.active_on' do
    let(:date) { Date.new(2024, 6, 1) }
    let!(:spanning) { create(:affiliation, start_date: Date.new(2023, 1, 1), end_date: Date.new(2025, 1, 1)) }
    let!(:open_ended) { create(:affiliation, start_date: Date.new(2023, 1, 1), end_date: nil) }
    let!(:ended_before) { create(:affiliation, start_date: Date.new(2020, 1, 1), end_date: Date.new(2021, 1, 1)) }
    let!(:starts_after) { create(:affiliation, start_date: Date.new(2025, 1, 1), end_date: nil) }
    let!(:no_dates) { create(:affiliation, start_date: nil, end_date: nil) }

    it 'includes affiliations whose span covers the date' do
      expect(described_class.active_on(date)).to include(spanning, open_ended)
    end

    it 'excludes affiliations that ended before the date' do
      expect(described_class.active_on(date)).not_to include(ended_before)
    end

    it 'excludes affiliations that start after the date' do
      expect(described_class.active_on(date)).not_to include(starts_after)
    end

    it 'includes affiliations with no dates on record' do
      expect(described_class.active_on(date)).to include(no_dates)
    end

    it 'ignores the cached inactive flag, judging purely by dates' do
      flagged = create(:affiliation, start_date: Date.new(2023, 1, 1), end_date: nil, inactive: true)
      expect(described_class.active_on(date)).to include(flagged)
    end
  end

  describe 'status (#status_on and .with_status)' do
    let!(:active_open) { create(:affiliation, start_date: Date.current.prev_year, end_date: nil) }
    let!(:active_span) { create(:affiliation, start_date: Date.current.prev_year, end_date: Date.current.next_year) }
    let!(:upcoming) { create(:affiliation, start_date: Date.current.next_year, end_date: nil) }
    let!(:ended) { create(:affiliation, start_date: Date.current.prev_year(2), end_date: Date.current.prev_year) }
    let!(:no_dates) { create(:affiliation, start_date: nil, end_date: nil) }

    it 'exposes the taxonomy in display order' do
      expect(Affiliation::STATUSES).to eq(%w[ Active Upcoming Inactive ])
    end

    it '#status_on classifies by flag and dates' do
      expect(active_open.reload.status_on).to eq("Active")
      expect(active_span.reload.status_on).to eq("Active")
      expect(upcoming.reload.status_on).to eq("Upcoming")
      expect(ended.reload.status_on).to eq("Inactive")
      expect(no_dates.reload.status_on).to eq("Active")
    end

    it '.with_status returns exactly the rows whose #status_on matches (SQL ↔ Ruby agree)' do
      Affiliation::STATUSES.each do |status|
        expected = Affiliation.all.select { |a| a.status_on == status }.map(&:id).sort
        expect(Affiliation.with_status(status).ids.sort).to eq(expected), "mismatch for #{status}"
      end
    end

    it 'offers the combined filter option alongside the chip taxonomy' do
      expect(Affiliation::FILTER_STATUSES)
        .to eq([ "Active", "Upcoming", "Active & Upcoming", "Inactive" ])
    end

    it '.with_status("Active & Upcoming") returns exactly the Active and Upcoming rows' do
      expected = Affiliation.all.select { |a| a.status_on.in?(%w[ Active Upcoming ]) }.map(&:id).sort

      expect(Affiliation.with_status(Affiliation::ACTIVE_OR_UPCOMING).ids.sort).to eq(expected)
      expect(Affiliation.with_status(Affiliation::ACTIVE_OR_UPCOMING)).to include(active_open, active_span, upcoming, no_dates)
      expect(Affiliation.with_status(Affiliation::ACTIVE_OR_UPCOMING)).not_to include(ended)
    end

    it '.with_status is empty for an unknown status' do
      expect(Affiliation.with_status("bogus")).to be_empty
    end
  end

  describe '#set_inactive_from_dates' do
    let(:op) { create(:affiliation, inactive: false, end_date: nil) }

    it 'sets inactive to true when end_date is set to a past date' do
      op.update!(end_date: 1.day.ago)
      expect(op.reload.inactive).to be true
    end

    it 'sets inactive to false when end_date is set to a future date' do
      op.update!(inactive: true, end_date: 1.day.ago)
      op.update!(end_date: 1.month.from_now)
      expect(op.reload.inactive).to be false
    end

    it 'sets inactive to false when end_date is cleared' do
      op.update!(end_date: 1.day.ago)
      op.update!(end_date: nil)
      expect(op.reload.inactive).to be false
    end

    it 'does not change inactive when unrelated fields change' do
      op.update!(inactive: true)
      op.update!(title: "New Title")
      expect(op.reload.inactive).to be true
    end
  end

  describe "reassigning the organization" do
    let(:old_org) { create(:organization) }
    let(:new_org) { create(:organization) }
    let(:old_address) { create(:address, addressable: old_org) }

    it "drops the stale address when the new org has several addresses" do
      create_list(:address, 2, addressable: new_org)
      affiliation = create(:affiliation, organization: old_org, organization_address: old_address)

      affiliation.update!(organization: new_org)

      expect(affiliation.reload.organization_id).to eq(new_org.id)
      expect(affiliation.organization_address_id).to be_nil
    end

    it "adopts the sole address of the new org" do
      new_address = create(:address, addressable: new_org)
      affiliation = create(:affiliation, organization: old_org, organization_address: old_address)

      affiliation.update!(organization: new_org)

      expect(affiliation.reload.organization_address_id).to eq(new_address.id)
    end
  end

  describe "the registration that created the affiliation" do
    it "drops the link when the affiliation is moved to a different organization" do
      registration = create(:event_registration)
      affiliation = create(:affiliation, event_registration: registration)
      other_org = create(:organization)

      affiliation.update!(organization: other_org)

      expect(affiliation.reload.event_registration_id).to be_nil
    end

    it "keeps the link when other attributes change" do
      registration = create(:event_registration)
      affiliation = create(:affiliation, event_registration: registration)

      affiliation.update!(title: "Lead Facilitator")

      expect(affiliation.reload.event_registration).to eq(registration)
    end
  end
end
