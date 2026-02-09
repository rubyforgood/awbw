require 'rails_helper'

RSpec.describe Notification do
  describe 'associations' do
    it { should belong_to(:noticeable).optional }
    it { should belong_to(:parent_notification).class_name('Notification').optional }
    it { should belong_to(:root_notification).class_name('Notification').optional }
    it { should have_many(:child_notifications).class_name('Notification').with_foreign_key(:parent_notification_id) }
  end

  describe '#resend?' do
    it 'returns true when notification has a parent' do
      parent = create(:notification)
      resend = create(:notification, parent_notification_id: parent.id)

      expect(resend.resend?).to be true
    end

    it 'returns false when notification has no parent' do
      notification = create(:notification)

      expect(notification.resend?).to be false
    end
  end

  describe '#resend_count' do
    it 'returns 0 for original notification with no resends' do
      notification = create(:notification)

      expect(notification.resend_count).to eq(0)
    end

    it 'returns correct count for notifications with resends' do
      original = create(:notification)
      create(:notification, parent_notification_id: original.id, root_notification_id: original.id)
      create(:notification, parent_notification_id: original.id, root_notification_id: original.id)

      expect(original.resend_count).to eq(2)
    end

    it 'counts all resends in the chain from root' do
      original = create(:notification)
      first_resend = create(:notification, parent_notification_id: original.id, root_notification_id: original.id)
      second_resend = create(:notification, parent_notification_id: first_resend.id, root_notification_id: original.id)

      expect(original.resend_count).to eq(2)
      expect(first_resend.resend_count).to eq(2)
      expect(second_resend.resend_count).to eq(2)
    end
  end

  describe '#original_notification' do
    it 'returns self when notification is the original' do
      notification = create(:notification)

      expect(notification.original_notification).to eq(notification)
    end

    it 'returns root notification when notification is a resend' do
      original = create(:notification)
      resend = create(:notification, parent_notification_id: original.id, root_notification_id: original.id)

      expect(resend.original_notification).to eq(original)
    end
>>>>>>> a9e429ca (Replace resend boolean with parent/root notification tracking for resend chain management)
  end
end
