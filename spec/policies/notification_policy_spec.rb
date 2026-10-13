require "rails_helper"

RSpec.describe NotificationPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user, email: "user@example.com" }
  let(:notification) { build_stubbed :notification, recipient_email: "user@example.com" }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "#index?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:index?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:index?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:index?) }
    end
  end

  describe "#show?" do
    context "with admin user" do
      subject { policy_for(record: notification, user: admin_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with owner user" do
      subject { policy_for(record: notification, user: regular_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with different user" do
      let(:other_user) { build_stubbed :user, email: "other@example.com" }
      subject { policy_for(record: notification, user: other_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end
  end

  describe "#new? and #create?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:new?) }
      it { is_expected.to be_allowed_to(:create?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:new?) }
      it { is_expected.not_to be_allowed_to(:create?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:new?) }
      it { is_expected.not_to be_allowed_to(:create?) }
    end
  end

  describe "#update?" do
    context "with admin user" do
      subject { policy_for(record: notification, user: admin_user) }

      it { is_expected.to be_allowed_to(:update?) }
    end

    context "with owner user" do
      subject { policy_for(record: notification, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:update?) }
    end

    context "with no user" do
      subject { policy_for(record: notification, user: nil) }

      it { is_expected.not_to be_allowed_to(:update?) }
    end
  end

  describe "relation_scope" do
    let!(:portal) do
      create(:notification, recipient_email: "user@example.com", channel: "autoemail",
                            kind: "form_submission_confirmation", recipient_role: "person")
    end
    let!(:hand_logged) do
      create(:notification, recipient_email: "user@example.com", channel: "phone",
                            kind: "manual_log", recipient_role: "person", email_subject: "Left a voicemail")
    end
    let!(:bulk_blast) do
      create(:notification, recipient_email: "user@example.com", channel: "autoemail", bulk: true,
                            kind: "event_registration_reminder", recipient_role: "person")
    end
    let!(:someone_elses) do
      create(:notification, recipient_email: "other@example.com", channel: "autoemail",
                            kind: "form_submission_confirmation", recipient_role: "person")
    end

    def scoped_for(user)
      described_class.new(user: user).apply_scope(Notification.all, type: :active_record_relation)
    end

    it "returns every communication for an admin" do
      expect(scoped_for(admin_user)).to contain_exactly(portal, hand_logged, bulk_blast, someone_elses)
    end

    it "returns portal-sent emails (transactional and bulk) addressed to a non-admin" do
      expect(scoped_for(regular_user)).to contain_exactly(portal, bulk_blast)
    end

    it "returns nothing for a guest" do
      expect(scoped_for(nil)).to be_empty
    end
  end

  describe "#resend?" do
    context "with admin user" do
      subject { policy_for(record: notification, user: admin_user) }

      it { is_expected.to be_allowed_to(:resend?) }
    end

    context "with admin user and Devise-originated notification" do
      let(:devise_notification) { build_stubbed :notification, kind: "account_confirmation" }
      subject { policy_for(record: devise_notification, user: admin_user) }

      it { is_expected.not_to be_allowed_to(:resend?) }
    end

    context "with owner user" do
      subject { policy_for(record: notification, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:resend?) }
    end

    context "with no user" do
      subject { policy_for(record: notification, user: nil) }

      it { is_expected.not_to be_allowed_to(:resend?) }
    end
  end
end
