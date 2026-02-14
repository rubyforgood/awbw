require 'rails_helper'

RSpec.describe OrganizationPerson do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:person) }
  end

  describe 'validations' do
    subject do
      build(:organization_person, organization: create(:organization), person: create(:person))
    end
    it { should validate_presence_of(:organization_id) }
  end

  describe 'enums' do
    it { should define_enum_for(:position).with_values(default: 0, liaison: 1, leader: 2, assistant: 3) }
  end

  describe '.active' do
    let!(:active_op) { create(:organization_person, inactive: false, end_date: nil) }
    let!(:active_with_future_end) { create(:organization_person, inactive: false, end_date: 1.month.from_now) }
    let!(:inactive_by_flag) { create(:organization_person, inactive: true, end_date: nil) }
    let!(:inactive_by_end_date) { create(:organization_person, inactive: false, end_date: 1.day.ago) }

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
  end

  describe '#set_inactive_from_dates' do
    let(:op) { create(:organization_person, inactive: false, end_date: nil) }

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
