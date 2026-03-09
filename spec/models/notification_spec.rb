require 'rails_helper'

RSpec.describe Notification do
  describe 'associations' do
    it { should belong_to(:noticeable).optional }
    it { should belong_to(:parent_notification).class_name('Notification').optional }
    it { should belong_to(:root_notification).class_name('Notification').optional }
    it { should have_many(:child_notifications).class_name('Notification').with_foreign_key(:parent_notification_id) }
  end

  describe "KINDS" do
    it "includes account_email_change_requested" do
      expect(Notification::KINDS).to include("account_email_change_requested")
    end

    it "includes account_email_changed" do
      expect(Notification::KINDS).to include("account_email_changed")
    end

    it "validates account_email_change_requested as a valid kind" do
      notification = build(:notification, kind: "account_email_change_requested", recipient_role: "person")
      expect(notification).to be_valid
    end

    it "validates account_email_changed as a valid kind" do
      notification = build(:notification, kind: "account_email_changed", recipient_role: "person")
      expect(notification).to be_valid
    end
  end

  describe "#resendable?" do
    it "returns true for notification kinds handled by the mailer job" do
      notification = build(:notification, kind: "reset_password_fyi")

      expect(notification.resendable?).to be true
    end

    it "returns false for Devise-originated kinds that require tokens" do
      Notification::DEVISE_KINDS.each do |devise_kind|
        notification = build(:notification, kind: devise_kind)

        expect(notification.resendable?).to be(false), "Expected #{devise_kind} to not be resendable"
      end
    end
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
  end

  describe '#resend_number' do
    it 'returns nil for original notification' do
      notification = create(:notification)

      expect(notification.resend_number).to be_nil
    end

    it 'returns 1 for first resend' do
      original = create(:notification)
      first_resend = create(:notification, parent_notification_id: original.id, root_notification_id: original.id)

      expect(first_resend.resend_number).to eq(1)
    end

    it 'returns correct position for multiple resends' do
      original = create(:notification)
      first_resend = create(:notification, parent_notification_id: original.id, root_notification_id: original.id)
      second_resend = create(:notification, parent_notification_id: first_resend.id, root_notification_id: original.id)
      third_resend = create(:notification, parent_notification_id: second_resend.id, root_notification_id: original.id)

      expect(first_resend.resend_number).to eq(1)
      expect(second_resend.resend_number).to eq(2)
      expect(third_resend.resend_number).to eq(3)
    end
  end

  describe "#failed?" do
    it "returns true when error_at is present and not delivered" do
      notification = create(:notification, error_at: Time.current, delivered_at: nil)

      expect(notification.failed?).to be true
    end

    it "returns false when delivered even with error_at" do
      notification = create(:notification, error_at: Time.current, delivered_at: Time.current)

      expect(notification.failed?).to be false
    end

    it "returns false when no error_at" do
      notification = create(:notification, error_at: nil, delivered_at: nil)

      expect(notification.failed?).to be false
    end
  end

  describe "#record_error!" do
    it "stores exception details on the notification" do
      notification = create(:notification)
      error = StandardError.new("SMTP connection refused")

      notification.record_error!(error)
      notification.reload

      expect(notification.error_message).to eq("SMTP connection refused")
      expect(notification.error_class).to eq("StandardError")
      expect(notification.error_at).to be_present
    end

    it "truncates long error messages" do
      notification = create(:notification)
      error = StandardError.new("x" * 600)

      notification.record_error!(error)

      expect(notification.error_message.length).to be <= 500
    end
  end

  describe '.search_by_params' do
    let!(:notification_alice) { create(:notification, recipient_email: 'alice@example.com', email_subject: 'Welcome to AWBW') }
    let!(:notification_bob) { create(:notification, recipient_email: 'bob@example.com', email_subject: 'Password Reset') }

    it 'returns all when no params' do
      results = Notification.search_by_params({})
      expect(results).to include(notification_alice, notification_bob)
    end

    it 'filters by email' do
      results = Notification.search_by_params(email: 'alice')
      expect(results).to include(notification_alice)
      expect(results).not_to include(notification_bob)
    end

    it 'filters by subject_line' do
      results = Notification.search_by_params(subject_line: 'Welcome')
      expect(results).to include(notification_alice)
      expect(results).not_to include(notification_bob)
    end

    it 'chains email and subject_line filters' do
      results = Notification.search_by_params(email: 'alice', subject_line: 'Welcome')
      expect(results).to include(notification_alice)
      expect(results).not_to include(notification_bob)
    end
  end
end
