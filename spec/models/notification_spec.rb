require 'rails_helper'

RSpec.describe Notification do
  describe "Ahoy lifecycle tracking" do
    after { Current.reset }

    # Notifications are excluded from create/update tracking — they're already a
    # durable, timestamped log, so an event per email sent would be redundant.
    # The activities page surfaces them from the notifications table instead.
    it "does not emit create lifecycle events, even in a user context" do
      allow(Analytics::LifecycleBuffer).to receive(:push)
      noticeable = create(:user)
      Current.user = create(:user)

      create(:notification, noticeable: noticeable)

      expect(Analytics::LifecycleBuffer).not_to have_received(:push)
        .with(hash_including(name: "create.notification"))
    end

    # Deletes are the exception — a removed communication should not vanish silently.
    it "emits a destroy lifecycle event when a communication is deleted" do
      allow(Analytics::LifecycleBuffer).to receive(:push)
      Current.user = create(:user)
      notification = create(:notification)

      notification.destroy

      expect(Analytics::LifecycleBuffer).to have_received(:push)
        .with(hash_including(name: "destroy.notification"))
    end
  end

  describe 'associations' do
    it { should belong_to(:noticeable).optional }
    it { should belong_to(:parent_notification).class_name('Notification').optional }
    it { should belong_to(:root_notification).class_name('Notification').optional }
    it { should have_many(:child_notifications).class_name('Notification').with_foreign_key(:parent_notification_id) }
  end

  describe "when its subject record is deleted" do
    # notifications are the durable record of what we sent — deleting the person
    # or registration a message was about must not destroy that history, so the
    # link is nullified and the communication survives as an orphaned record.
    it "is nullified, not destroyed, when the person is deleted" do
      person = create(:person)
      notification = create(:notification, noticeable: person)

      expect { person.destroy }.not_to change(Notification, :count)
      expect(notification.reload.noticeable).to be_nil
    end

    it "is nullified, not destroyed, when the event registration is deleted" do
      registration = create(:event_registration)
      notification = create(:notification, noticeable: registration)

      expect { registration.destroy }.not_to change(Notification, :count)
      expect(notification.reload.noticeable).to be_nil
    end

    it "is nullified, not destroyed, when the subject user account is deleted" do
      user = create(:user)
      notification = create(:notification, noticeable: user)

      expect { user.destroy }.not_to change(Notification, :count)
      expect(notification.reload.noticeable).to be_nil
    end
  end

  describe "manual log channel" do
    def build_notification(**attrs)
      build(:notification, recipient_role: "person", recipient_email: "x@example.com", notification_type: 0, **attrs)
    end

    it "coerces a hand-logged (manual_log) autoemail channel to email" do
      notification = build_notification(kind: "manual_log", channel: "autoemail")
      notification.valid?
      expect(notification.channel).to eq("email")
    end

    it "defaults a channel-less hand-logged communication to email, not the autoemail column default" do
      notification = build_notification(kind: "manual_log", channel: nil)
      notification.valid?
      expect(notification.channel).to eq("email")
    end

    it "keeps a chosen manual channel" do
      notification = build_notification(kind: "manual_log", channel: "phone")
      notification.valid?
      expect(notification.channel).to eq("phone")
    end

    it "leaves autoemail on a portal-sent notification" do
      notification = build_notification(kind: "event_registration_confirmation", channel: "autoemail")
      notification.valid?
      expect(notification.channel).to eq("autoemail")
    end

    it "defaults a blank kind with a manual channel to manual_log" do
      notification = build_notification(kind: nil, channel: "phone")
      notification.valid?
      expect(notification.kind).to eq("manual_log")
    end

    it "does not overwrite an already-set kind when a manual channel is present" do
      notification = build_notification(kind: "event_registration_confirmation", channel: "phone")
      notification.valid?
      expect(notification.kind).to eq("event_registration_confirmation")
    end

    it "leaves the kind of an autoemail alone" do
      notification = build_notification(kind: "event_registration_confirmation", channel: "autoemail")
      notification.valid?
      expect(notification.kind).to eq("event_registration_confirmation")
    end
  end

  describe "direction" do
    it "defaults to outgoing" do
      expect(Notification.new.direction).to eq("outgoing")
    end

    it "is invalid with an unknown direction" do
      notification = build(:notification, direction: "sideways")
      expect(notification).not_to be_valid
      expect(notification.errors[:direction]).to be_present
    end

    it "reports incoming? for an incoming communication" do
      expect(build(:notification, :incoming)).to be_incoming
    end

    it "does not report incoming? for an outgoing communication" do
      expect(build(:notification)).not_to be_incoming
    end
  end

  describe "recipient_name caching" do
    it "snapshots the contact person's name from recipient_email on create" do
      person = create(:person, first_name: "Casey", last_name: "Contact", email: "casey@example.com")
      notification = create(:notification, recipient_email: person.email)
      expect(notification.recipient_name).to eq(person.name)
    end

    it "resolves a person by their secondary email" do
      person = create(:person, first_name: "Casey", last_name: "Contact", email_2: "casey2@example.com")
      notification = create(:notification, recipient_email: "casey2@example.com")
      expect(notification.recipient_name).to eq(person.name)
    end

    it "leaves recipient_name blank when no person matches" do
      notification = create(:notification, recipient_email: "unknown@example.com")
      expect(notification.recipient_name).to be_nil
    end

    it "does not overwrite a caller-supplied recipient_name" do
      create(:person, first_name: "Casey", last_name: "Contact", email: "casey@example.com")
      notification = create(:notification, recipient_email: "casey@example.com", recipient_name: "Custom Name")
      expect(notification.recipient_name).to eq("Custom Name")
    end
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

  describe ".responded_status" do
    let!(:fyi_responded)          { create(:notification, kind: "contact_us_fyi", responded: true) }
    let!(:fyi_not_responded)      { create(:notification, kind: "contact_us_fyi", responded: false) }
    let!(:incoming_responded)     { create(:notification, :incoming, responded: true) }
    let!(:incoming_not_responded) { create(:notification, :incoming, responded: false) }
    let!(:contact_us)             { create(:notification, kind: "contact_us") }
    let!(:other)                  { create(:notification, kind: "reset_password_fyi") }

    it "returns responded contact_us_fyi and incoming notifications for 'yes'" do
      expect(Notification.responded_status("yes")).to contain_exactly(fyi_responded, incoming_responded)
    end

    it "returns unresponded contact_us_fyi and incoming notifications for 'no'" do
      expect(Notification.responded_status("no")).to contain_exactly(fyi_not_responded, incoming_not_responded)
    end

    it "returns notifications that are neither contact_us_fyi nor incoming for 'na'" do
      expect(Notification.responded_status("na")).to contain_exactly(contact_us, other)
    end

    it "returns all notifications for blank/unknown values" do
      all = [ fyi_responded, fyi_not_responded, incoming_responded, incoming_not_responded, contact_us, other ]
      expect(Notification.responded_status("")).to contain_exactly(*all)
      expect(Notification.responded_status("bogus")).to contain_exactly(*all)
    end
  end

  describe "#requires_response?" do
    it "returns true for contact_us_fyi kind" do
      expect(build(:notification, kind: "contact_us_fyi").requires_response?).to be true
    end

    it "returns false for an outgoing manual log" do
      expect(build(:notification, kind: "manual_log").requires_response?).to be false
    end

    it "returns false for contact_us kind (auto-confirmation to submitter)" do
      expect(build(:notification, kind: "contact_us").requires_response?).to be false
    end

    it "returns false for other kinds" do
      expect(build(:notification, kind: "reset_password_fyi").requires_response?).to be false
    end

    it "returns true for an incoming communication regardless of kind" do
      expect(build(:notification, :incoming, kind: "reset_password_fyi").requires_response?).to be true
    end
  end

  describe "contact_us_fyi direction" do
    it "is marked incoming when created" do
      expect(create(:notification, kind: "contact_us_fyi").direction).to eq("incoming")
    end

    it "forces incoming even when built as outgoing" do
      expect(create(:notification, kind: "contact_us_fyi", direction: "outgoing").direction).to eq("incoming")
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

  describe "#stuck_pending?" do
    it "is true when undelivered past the grace period" do
      notification = create(:notification, delivered_at: nil, error_at: nil, created_at: 2.hours.ago)

      expect(notification.stuck_pending?).to be true
    end

    it "is false while still within the grace period (a normal in-flight send)" do
      notification = create(:notification, delivered_at: nil, error_at: nil, created_at: 5.minutes.ago)

      expect(notification.stuck_pending?).to be false
    end

    it "is false once delivered" do
      notification = create(:notification, delivered_at: Time.current, created_at: 2.hours.ago)

      expect(notification.stuck_pending?).to be false
    end

    it "is false when failed (that is an error, not a stuck-pending state)" do
      notification = create(:notification, error_at: Time.current, delivered_at: nil, created_at: 2.hours.ago)

      expect(notification.stuck_pending?).to be false
    end

    it "is false once archived (pre-launch), even past the grace period" do
      notification = create(:notification, delivered_at: nil, error_at: nil, created_at: Date.new(2025, 12, 1))

      expect(notification.stuck_pending?).to be false
    end
  end

  describe "#archived?" do
    it "is true for an undelivered email created before launch" do
      expect(build(:notification, delivered_at: nil, error_at: nil, created_at: Date.new(2025, 12, 1)).archived?).to be true
    end

    it "is false for an undelivered email created on/after launch" do
      expect(build(:notification, delivered_at: nil, error_at: nil, created_at: Notification::LAUNCHED_ON).archived?).to be false
    end

    it "is false when delivered, even if created before launch" do
      expect(build(:notification, delivered_at: Time.current, created_at: Date.new(2025, 12, 1)).archived?).to be false
    end

    it "is false when failed, even if created before launch" do
      expect(build(:notification, delivered_at: nil, error_at: Time.current, created_at: Date.new(2025, 12, 1)).archived?).to be false
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

    context 'email_topic filter' do
      let!(:welcome_notification) { create(:notification, email_subject: "AWBW Portal: Welcome instructions for Jane") }
      let!(:password_notification) { create(:notification, email_subject: "AWBW Portal: Password reset request for Jane") }
      let!(:event_notification) { create(:notification, email_subject: "AWBW Portal: Event registration received for Art Show") }

      it 'filters by email_topic keyword' do
        results = Notification.search_by_params(email_topic: "User: welcome instructions")
        expect(results).to include(welcome_notification)
        expect(results).not_to include(password_notification, event_notification)
      end

      it 'returns all when email_topic is blank' do
        results = Notification.search_by_params(email_topic: "")
        expect(results).to include(welcome_notification, password_notification, event_notification)
      end

      it 'chains email_topic and subject_line with AND' do
        results = Notification.search_by_params(email_topic: "User: welcome instructions", subject_line: "Jane")
        expect(results).to include(welcome_notification)
        expect(results).not_to include(password_notification, event_notification)
      end

      it 'subject_line alone still works as AND with other filters' do
        results = Notification.search_by_params(subject_line: "Jane")
        expect(results).to include(welcome_notification, password_notification)
        expect(results).not_to include(event_notification)
      end

      it 'Admin FYI (all) matches all FYI emails' do
        fyi_event = create(:notification, email_subject: "AWBW Portal: [FYI] New event registration by Jane to Art Show")
        fyi_cancel = create(:notification, email_subject: "AWBW Portal: [FYI] Event registration cancelled by Jane for Art Show")
        fyi_submission = create(:notification, email_subject: "AWBW Portal: [FYI] New StoryIdea submission by Jane")
        fyi_reset = create(:notification, email_subject: "AWBW Portal: [FYI] New password reset by Jane")

        results = Notification.search_by_params(email_topic: "Admin FYI (all)")
        expect(results).to include(fyi_event, fyi_cancel, fyi_submission, fyi_reset)
        expect(results).not_to include(welcome_notification, password_notification, event_notification)
      end

      it 'granular FYI topics match only their specific type' do
        fyi_event = create(:notification, email_subject: "AWBW Portal: [FYI] New event registration by Jane to Art Show")
        fyi_cancel = create(:notification, email_subject: "AWBW Portal: [FYI] Event registration cancelled by Jane for Art Show")
        fyi_submission = create(:notification, email_subject: "AWBW Portal: [FYI] New StoryIdea submission by Jane")

        results = Notification.search_by_params(email_topic: "Admin FYI: event registration confirmed")
        expect(results).to include(fyi_event)
        expect(results).not_to include(fyi_cancel, fyi_submission)
      end

      it 'separates scholarship event registrations from plain ones' do
        plain_confirmed = create(:notification, email_subject: "AWBW Portal: Event registration received for Art Show")
        scholarship_confirmed = create(:notification, email_subject: "AWBW Portal: Event scholarship registration received for Art Show")
        fyi_plain = create(:notification, email_subject: "AWBW Portal: [FYI] New event registration by Jane to Art Show")
        fyi_scholarship = create(:notification, email_subject: "AWBW Portal: [FYI] New event scholarship registration by Jane to Art Show")

        plain_results = Notification.search_by_params(email_topic: "Event registration received")
        expect(plain_results).to include(plain_confirmed)
        expect(plain_results).not_to include(scholarship_confirmed)

        scholarship_results = Notification.search_by_params(email_topic: "Event scholarship registration received")
        expect(scholarship_results).to include(scholarship_confirmed)
        expect(scholarship_results).not_to include(plain_confirmed)

        fyi_plain_results = Notification.search_by_params(email_topic: "Admin FYI: event registration confirmed")
        expect(fyi_plain_results).to include(fyi_plain)
        expect(fyi_plain_results).not_to include(fyi_scholarship)

        fyi_scholarship_results = Notification.search_by_params(email_topic: "Admin FYI: event scholarship registration confirmed")
        expect(fyi_scholarship_results).to include(fyi_scholarship)
        expect(fyi_scholarship_results).not_to include(fyi_plain)
      end

      it 'Idea confirmation (all) matches idea and workshop log confirmations' do
        idea_conf = create(:notification, email_subject: "AWBW Portal: Your story idea has been received")
        log_conf = create(:notification, email_subject: "AWBW Portal: Your workshop log has been received")

        results = Notification.search_by_params(email_topic: "Idea: confirmation (all)")
        expect(results).to include(idea_conf, log_conf)
        expect(results).not_to include(welcome_notification)
      end

      it 'Event registration received does not return cancelled emails' do
        confirmed = create(:notification, email_subject: "AWBW Portal: Event registration received for Art Show")
        cancelled = create(:notification, email_subject: "AWBW Portal: Event registration cancelled for Art Show")

        results = Notification.search_by_params(email_topic: "Event registration received")
        expect(results).to include(confirmed)
        expect(results).not_to include(cancelled)
      end

      it 'ignores an unrecognized email_topic label' do
        results = Notification.search_by_params(email_topic: "Nonexistent topic")
        expect(results).to include(welcome_notification, password_notification, event_notification)
      end
    end

    context 'record_type filter' do
      let!(:notification_story) { create(:notification, noticeable: create(:story_idea)) }
      let!(:notification_user) { create(:notification, noticeable: create(:user)) }

      it 'filters by record_type' do
        results = Notification.search_by_params(record_type: "StoryIdea")
        expect(results).to include(notification_story)
        expect(results).not_to include(notification_user)
      end

      it 'returns all when record_type is blank' do
        results = Notification.search_by_params(record_type: "")
        expect(results).to include(notification_story, notification_user)
      end
    end
  end
end
