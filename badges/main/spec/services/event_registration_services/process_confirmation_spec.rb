require "rails_helper"

RSpec.describe EventRegistrationServices::ProcessConfirmation do
  let(:admin) { create(:user, :with_person, super_user: true) }
  let(:event) { create(:event) }

  describe ".call" do
    context "with no actions selected" do
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "returns summary with no actions" do
        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: false,
          send_confirmation_email: false,
          send_admin_fyi: false,
          current_user: admin
        )

        expect(result.summary).to eq("Registration created.")
        expect(result.actions_taken).to be_empty
      end
    end

    context "create_user" do
      let(:person) { create(:person, email: "test@example.com") }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "creates a user account for a person without one" do
        registration # force lazy let evaluation
        admin
        person.user.destroy!
        person.reload

        expect {
          described_class.call(
            event_registration: registration,
            person: person,
            create_user: true,
            send_invite: false,
            send_confirmation_email: false,
            send_admin_fyi: false,
            current_user: admin
          )
        }.to change(User, :count).by(1)

        new_user = person.reload.user
        expect(new_user.email).to eq("test@example.com")
        expect(new_user.created_by).to eq(admin)
        expect(new_user.person).to eq(person)
      end

      it "does nothing when person already has a user" do
        registration # force lazy let evaluation
        admin

        expect {
          described_class.call(
            event_registration: registration,
            person: person,
            create_user: true,
            send_invite: false,
            send_confirmation_email: false,
            send_admin_fyi: false,
            current_user: admin
          )
        }.not_to change(User, :count)
      end
    end

    context "send_invite" do
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "sends welcome instructions to existing user" do
        user = person.user

        expect {
          described_class.call(
            event_registration: registration,
            person: person,
            create_user: false,
            send_invite: true,
            send_confirmation_email: false,
            send_admin_fyi: false,
            current_user: admin
          )
        }.to change { user.reload.welcome_instructions_sent_at }

        expect(user.reload.welcome_instructions_token).to be_present
      end

      it "records the current user as the sender" do
        user = person.user

        described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: true,
          send_confirmation_email: false,
          send_admin_fyi: false,
          current_user: admin
        )

        user.reload
        expect(user.welcome_instructions_sent_by).to eq(admin)
        expect(user.updated_by).to eq(admin)
      end

      it "does nothing when person has no user" do
        person.user.destroy!
        person.reload

        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: true,
          send_confirmation_email: false,
          send_admin_fyi: false,
          current_user: admin
        )

        expect(result.actions_taken).not_to include("System invite sent")
      end
    end

    context "send_confirmation_email" do
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "creates a notification for registration confirmation" do
        expect(NotificationServices::CreateNotification).to receive(:call).with(
          noticeable: registration,
          kind: "event_registration_confirmation",
          recipient_role: :person,
          recipient_email: person.preferred_email,
          notification_type: 0
        )

        described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: false,
          send_confirmation_email: true,
          send_admin_fyi: false,
          current_user: admin
        )
      end

      # Templated confirmations are automated even though an admin ticks the box —
      # only hand-written sends (invites, bulk reminders, resends) name a person.
      it "leaves the confirmation attributed to the portal, not the admin" do
        described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: false,
          send_confirmation_email: true,
          send_admin_fyi: false,
          current_user: admin
        )

        confirmation = Notification.where(kind: "event_registration_confirmation").last
        expect(confirmation.sender).to be_nil
        expect(confirmation.decorate.sender_name).to eq(NotificationDecorator::PORTAL_SENDER_NAME)
      end
    end

    context "send_admin_fyi" do
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "creates a notification for admin FYI" do
        expect(NotificationServices::CreateNotification).to receive(:call).with(
          noticeable: registration,
          kind: "event_registration_confirmation_fyi",
          recipient_role: :admin,
          recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
          notification_type: 0
        )

        described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: false,
          send_confirmation_email: false,
          send_admin_fyi: true,
          current_user: admin
        )
      end
    end

    context "create_user + send_invite combined" do
      let(:person) { create(:person, email: "combo@example.com") }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "creates user then sends invite in sequence" do
        person.user.destroy!
        person.reload

        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: true,
          send_invite: true,
          send_confirmation_email: false,
          send_admin_fyi: false,
          current_user: admin
        )

        expect(result.actions_taken).to include("User account created")
        expect(result.actions_taken).to include("System invite sent")
        expect(person.reload.user).to be_present
        expect(person.user.welcome_instructions_token).to be_present
      end
    end

    context "all four actions selected" do
      let(:person) { create(:person, email: "all@example.com") }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "creates user, sends invite, and both emails" do
        person.user.destroy!
        person.reload
        allow(NotificationServices::CreateNotification).to receive(:call)

        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: true,
          send_invite: true,
          send_confirmation_email: true,
          send_admin_fyi: true,
          current_user: admin
        )

        expect(result.actions_taken).to contain_exactly(
          "User account created",
          "System invite sent",
          "Registration confirmation email sent",
          "Admin notification email sent"
        )
        expect(person.reload.user).to be_present
        expect(person.user.welcome_instructions_token).to be_present
      end
    end

    context "only emails selected (no user actions)" do
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "sends both emails without touching user accounts" do
        registration # force lazy let evaluation
        admin
        allow(NotificationServices::CreateNotification).to receive(:call)

        expect {
          described_class.call(
            event_registration: registration,
            person: person,
            create_user: false,
            send_invite: false,
            send_confirmation_email: true,
            send_admin_fyi: true,
            current_user: admin
          )
        }.not_to change(User, :count)

        expect(NotificationServices::CreateNotification).to have_received(:call).twice
      end
    end

    context "only admin FYI selected" do
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "sends only the admin notification" do
        allow(NotificationServices::CreateNotification).to receive(:call)

        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: false,
          send_confirmation_email: false,
          send_admin_fyi: true,
          current_user: admin
        )

        expect(result.actions_taken).to eq([ "Admin notification email sent" ])
        expect(NotificationServices::CreateNotification).to have_received(:call).once
      end
    end

    context "send_invite without create_user for unconfirmed user" do
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "sends invite to existing unconfirmed user" do
        person.user.update!(confirmed_at: nil)

        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: true,
          send_confirmation_email: false,
          send_admin_fyi: false,
          current_user: admin
        )

        expect(result.actions_taken).to eq([ "System invite sent" ])
        expect(person.user.reload.welcome_instructions_token).to be_present
      end
    end

    context "create_user without send_invite" do
      let(:person) { create(:person, email: "noinvite@example.com") }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "creates user but does not send welcome email" do
        person.user.destroy!
        person.reload

        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: true,
          send_invite: false,
          send_confirmation_email: false,
          send_admin_fyi: false,
          current_user: admin
        )

        expect(result.actions_taken).to eq([ "User account created" ])
        new_user = person.reload.user
        expect(new_user).to be_present
        expect(new_user.welcome_instructions_token).to be_nil
      end
    end

    context "result summary" do
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event: event, registrant: person) }

      it "uses to_sentence for multiple actions" do
        allow(NotificationServices::CreateNotification).to receive(:call)

        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: false,
          send_confirmation_email: true,
          send_admin_fyi: true,
          current_user: admin
        )

        expect(result.summary).to eq(
          "Registration created. Registration confirmation email sent and Admin notification email sent."
        )
      end

      it "formats single action without 'and'" do
        allow(NotificationServices::CreateNotification).to receive(:call)

        result = described_class.call(
          event_registration: registration,
          person: person,
          create_user: false,
          send_invite: false,
          send_confirmation_email: true,
          send_admin_fyi: false,
          current_user: admin
        )

        expect(result.summary).to eq("Registration created. Registration confirmation email sent.")
      end
    end
  end
end
