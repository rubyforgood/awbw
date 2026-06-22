require 'rails_helper'

RSpec.describe Affiliation do
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

    it 'excludes a future-dated (pending) affiliation' do
      pending_aff = create(:affiliation, inactive: false, start_date: 1.month.from_now)
      expect(described_class.active).not_to include(pending_aff)
    end
  end

  describe '.active_or_pending' do
    it 'includes a future-dated affiliation that .active excludes' do
      pending_aff = create(:affiliation, inactive: false, start_date: 1.month.from_now)

      expect(described_class.active_or_pending).to include(pending_aff)
      expect(described_class.active).not_to include(pending_aff)
    end

    it 'excludes inactive and ended affiliations like .active does' do
      inactive_aff = create(:affiliation, inactive: true)
      ended_aff = create(:affiliation, inactive: false, end_date: 1.day.ago)

      expect(described_class.active_or_pending).not_to include(inactive_aff, ended_aff)
    end
  end

  describe '#active_or_pending?' do
    it 'is true for a future start date (where #active? is false)' do
      affiliation = build(:affiliation, inactive: false, start_date: 1.month.from_now)

      expect(affiliation.active_or_pending?).to be true
      expect(affiliation.active?).to be false
    end

    it 'is false once ended' do
      expect(build(:affiliation, inactive: false, end_date: 1.day.ago).active_or_pending?).to be false
    end
  end

  describe 'organization status sync' do
    let!(:active_status) { create(:organization_status, name: "Active") }
    let!(:inactive_status) { create(:organization_status, name: "Inactive") }

    it 'reactivates an Inactive organization when it gains an active affiliation' do
      org = create(:organization, organization_status: inactive_status)

      create(:affiliation, organization: org, inactive: false, end_date: nil)

      expect(org.reload.organization_status).to eq(active_status)
    end

    it 'activates on a pending (future-dated) affiliation too' do
      org = create(:organization, organization_status: inactive_status)

      create(:affiliation, organization: org, inactive: false, start_date: 1.month.from_now)

      expect(org.reload.organization_status).to eq(active_status)
    end

    it 'deactivates an Active organization when its last affiliation ends' do
      org = create(:organization, organization_status: active_status)
      affiliation = create(:affiliation, organization: org, inactive: false, end_date: nil)

      affiliation.update!(end_date: 1.day.ago)

      expect(org.reload.organization_status).to eq(inactive_status)
    end

    it 'leaves a manually set status (e.g. Suspended) untouched' do
      suspended = create(:organization_status, name: "Suspended")
      org = create(:organization, organization_status: suspended)

      create(:affiliation, organization: org, inactive: false, end_date: nil)

      expect(org.reload.organization_status).to eq(suspended)
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
end
