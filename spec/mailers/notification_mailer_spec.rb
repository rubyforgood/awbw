require "rails_helper"

RSpec.describe NotificationMailer, type: :mailer do
  describe "#bulk_payment_confirmation_fyi" do
    let(:event) { create(:event) }
    let(:form) do
      f = FormBuilderService.new(name: "Bulk Payment", sections: %i[bulk_payment], role: "bulk_payment").call
      event.event_forms.create!(form: f, role: "bulk_payment")
      f
    end
    let(:person) { create(:person, first_name: "Pat", last_name: "Payer", email: "pat@example.com") }
    let(:submission) do
      s = FormSubmission.create!(form: form, person: person, event: event, role: "bulk_payment")
      s.form_answers.create!(form_field: form.form_fields.find_by(field_identifier: "number_of_attendees"), submitted_answer: "4")
      s
    end
    let(:notification) { create(:notification, kind: "bulk_payment_confirmation_fyi", noticeable: submission) }

    it "renders without raising" do
      expect { described_class.bulk_payment_confirmation_fyi(notification).deliver_now }.not_to raise_error
    end

    it "names the payer in the subject" do
      expect(described_class.bulk_payment_confirmation_fyi(notification).subject).to include("Pat Payer")
    end
  end

  describe "#event_registration_confirmation_fyi" do
    let(:notification) { create(:notification, kind: "event_registration_confirmation_fyi", noticeable: event_registration) }

    context "when a scholarship was not requested" do
      let(:event_registration) { create(:event_registration, scholarship_requested: false) }

      it "labels the subject as a plain event registration" do
        subject = described_class.event_registration_confirmation_fyi(notification).subject
        expect(subject).to include("New event registration by")
        expect(subject).not_to include("scholarship")
      end
    end

    context "when a scholarship was requested" do
      let(:event_registration) { create(:event_registration, scholarship_requested: true) }

      it "labels the subject as an event scholarship registration" do
        subject = described_class.event_registration_confirmation_fyi(notification).subject
        expect(subject).to include("New event scholarship registration by")
      end
    end

    context "for a virtual event" do
      let(:event) { create(:event, videoconference_url: "https://zoom.us/j/123", videoconference_label: "Zoom", videoconference_passcode: "secret123") }
      let(:event_registration) { create(:event_registration, event: event) }

      it "shows the platform label as plain text" do
        body = described_class.event_registration_confirmation_fyi(notification).body.encoded
        expect(body).to include("Zoom")
      end

      it "does not include the join link, meeting ID, or passcode" do
        body = described_class.event_registration_confirmation_fyi(notification).body.encoded
        expect(body).not_to include("https://zoom.us/j/123")
        expect(body).not_to include("secret123")
        expect(body).not_to include("Meeting ID")
      end
    end
  end

  describe "#report_submitted_fyi" do
    let(:notification) { create(:notification, kind: :report_submitted_fyi) }

    it "renders without raising" do
      expect {
        NotificationMailer.report_submitted_fyi(notification).deliver_now
      }.not_to raise_error
    end
  end

  describe "#idea_submitted_fyi" do
    let(:user) { create(:user) }

    context "with a story_idea as noticeable" do
      let(:story_idea) { create(:story_idea, created_by: user) }
      let(:notification) { create(:notification, kind: "idea_submitted_fyi", noticeable: story_idea) }

      it "renders without raising" do
        expect {
          described_class.idea_submitted_fyi(notification).deliver_now
        }.not_to raise_error
      end

      context "without a workshop or external title" do
        let(:story_idea) { create(:story_idea, created_by: user, workshop: nil, external_workshop_title: nil) }

        it "renders without raising" do
          expect {
            described_class.idea_submitted_fyi(notification).deliver_now
          }.not_to raise_error
        end
      end

      context "with attachments" do
        let(:primary_asset) { create(:primary_asset, :with_file, owner: story_idea) }
        let(:gallery_asset) { create(:gallery_asset, :with_file, owner: story_idea) }

        before do
          primary_asset
          gallery_asset
        end

        it "includes attachments in the email body" do
          mail = described_class.idea_submitted_fyi(notification)
          expect(mail.body.encoded).to include("Attachments")
          expect(mail.body.encoded).to include(primary_asset.file.filename.to_s)
          expect(mail.body.encoded).to include(gallery_asset.file.filename.to_s)
        end

        it "renders without raising" do
          expect {
            described_class.idea_submitted_fyi(notification).deliver_now
          }.not_to raise_error
        end
      end

      context "without attachments" do
        it "does not include Attachments section" do
          mail = described_class.idea_submitted_fyi(notification)
          expect(mail.body.encoded).not_to include("Attachments")
        end
      end
    end

    context "with a workshop_idea as noticeable" do
      let(:workshop_idea) { create(:workshop_idea, created_by: user, updated_by: user) }
      let(:notification) { create(:notification, kind: "idea_submitted_fyi", noticeable: workshop_idea) }

      it "renders without raising" do
        expect {
          described_class.idea_submitted_fyi(notification).deliver_now
        }.not_to raise_error
      end
    end

    context "with a workshop_variation_idea as noticeable" do
      let(:workshop_variation_idea) { create(:workshop_variation_idea, created_by: user, updated_by: user) }
      let(:notification) { create(:notification, kind: "idea_submitted_fyi", noticeable: workshop_variation_idea) }

      it "renders without raising" do
        expect {
          described_class.idea_submitted_fyi(notification).deliver_now
        }.not_to raise_error
      end
    end
  end

  describe "#workshop_log_submitted_fyi" do
    context "with a workshop" do
      let(:workshop_log) { create(:workshop_log) }
      let(:notification) { create(:notification, kind: "workshop_log_submitted_fyi", noticeable: workshop_log) }

      it "renders without raising" do
        expect {
          described_class.workshop_log_submitted_fyi(notification).deliver_now
        }.not_to raise_error
      end

      it "includes the workshop title" do
        mail = described_class.workshop_log_submitted_fyi(notification)
        expect(mail.body.encoded).to include(workshop_log.workshop.title)
      end
    end

    context "without a workshop (external title only)" do
      let(:workshop_log) do
        create(:workshop_log, workshop: nil, external_workshop_title: "Community Art Session")
      end
      let(:notification) { create(:notification, kind: "workshop_log_submitted_fyi", noticeable: workshop_log) }

      it "renders without raising" do
        expect {
          described_class.workshop_log_submitted_fyi(notification).deliver_now
        }.not_to raise_error
      end

      it "includes the external title" do
        mail = described_class.workshop_log_submitted_fyi(notification)
        expect(mail.body.encoded).to include("Community Art Session")
      end
    end
  end

  describe "#idea_submitted" do
    let(:user) { create(:user) }
    let(:story_idea) { create(:story_idea, created_by: user) }
    let(:notification) do
      create(:notification, kind: "idea_submitted", noticeable: story_idea,
             recipient_role: "person", recipient_email: user.email)
    end

    it "renders without raising" do
      expect {
        described_class.idea_submitted(notification).deliver_now
      }.not_to raise_error
    end

    it "sends to the submitter" do
      mail = described_class.idea_submitted(notification)
      expect(mail.to).to eq([ user.email ])
    end

    it "includes a confirmation message" do
      mail = described_class.idea_submitted(notification)
      expect(mail.body.encoded).to include("Submission received")
      expect(mail.body.encoded).to include("Thank you for your submission")
    end

    context "without a workshop or external title" do
      let(:story_idea) { create(:story_idea, created_by: user, workshop: nil, external_workshop_title: nil) }

      it "renders without raising" do
        expect {
          described_class.idea_submitted(notification).deliver_now
        }.not_to raise_error
      end
    end
  end

  describe "#workshop_log_submitted" do
    let(:user) { create(:user) }

    context "with a workshop" do
      let(:workshop_log) { create(:workshop_log, created_by: user) }
      let(:notification) do
        create(:notification, kind: "workshop_log_submitted", noticeable: workshop_log,
               recipient_role: "person", recipient_email: user.email)
      end

      it "renders without raising" do
        expect {
          described_class.workshop_log_submitted(notification).deliver_now
        }.not_to raise_error
      end

      it "sends to the submitter" do
        mail = described_class.workshop_log_submitted(notification)
        expect(mail.to).to eq([ user.email ])
      end

      it "includes the workshop title" do
        mail = described_class.workshop_log_submitted(notification)
        expect(mail.body.encoded).to include(workshop_log.workshop.title)
      end
    end

    context "without a workshop (external title only)" do
      let(:workshop_log) do
        create(:workshop_log, created_by: user, workshop: nil,
               external_workshop_title: "Community Art Session")
      end
      let(:notification) do
        create(:notification, kind: "workshop_log_submitted", noticeable: workshop_log,
               recipient_role: "person", recipient_email: user.email)
      end

      it "renders without raising" do
        expect {
          described_class.workshop_log_submitted(notification).deliver_now
        }.not_to raise_error
      end

      it "includes the external title" do
        mail = described_class.workshop_log_submitted(notification)
        expect(mail.body.encoded).to include("Community Art Session")
      end
    end
  end

  describe "#story_promoted" do
    let(:submitter) { create(:user, email: "submitter@example.com") }
    let(:story_idea) { create(:story_idea, created_by: submitter) }
    let(:story) { create(:story, :published, story_idea: story_idea, title: "A Healing Story") }
    let(:notification) do
      create(:notification, kind: "story_promoted", noticeable: story,
             recipient_role: "person", recipient_email: submitter.email)
    end

    it "renders without raising" do
      expect { described_class.story_promoted(notification).deliver_now }.not_to raise_error
    end

    it "sends to the idea's submitter" do
      expect(described_class.story_promoted(notification).to).to eq([ submitter.email ])
    end

    it "names the story and greets the submitter" do
      body = described_class.story_promoted(notification).body.encoded
      expect(body).to include("A Healing Story")
      expect(body).to include(submitter.full_name)
    end
  end

  describe "#story_promoted_fyi" do
    let(:submitter) { create(:user) }
    let(:story_idea) { create(:story_idea, created_by: submitter) }
    let(:story) { create(:story, story_idea: story_idea, title: "A Healing Story") }
    let(:notification) do
      create(:notification, kind: "story_promoted_fyi", noticeable: story,
             recipient_role: "admin",
             recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"))
    end

    it "renders without raising" do
      expect { described_class.story_promoted_fyi(notification).deliver_now }.not_to raise_error
    end

    it "goes to the admin mailbox" do
      expect(described_class.story_promoted_fyi(notification).to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
    end

    it "names the story in the subject" do
      expect(described_class.story_promoted_fyi(notification).subject).to include("A Healing Story")
    end
  end

  describe "#reset_password_fyi" do
    let(:user) { create(:user, email: "user@example.com") }
    let(:notification) { create(:notification, kind: "reset_password_fyi", noticeable: user) }
    let(:mail) { described_class.reset_password_fyi(notification) }

    subject(:mail) { described_class.reset_password_fyi(notification) }

    it "renders the headers" do
      expect(mail.subject).to include("AWBW Portal:")
      expect(mail.subject).to include("password reset")
      expect(mail.subject).to include(notification.noticeable.full_name)
      expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
      expect(mail.from).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
      expect(mail.reply_to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
    end

    it "renders the body" do
      # user.send_reset_password_instructions
      # user.reload
      expect(mail.body.encoded).to match("requested a password reset")
      # expect(mail.body.encoded).to match(user.reset_password_token)
    end

    it "includes the user email in the email body" do
      expect(mail.body.encoded).to include("user@example.com")
    end

    it "delivers the email" do
      expect {
        mail.deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    context "when the user's person has an avatar attached" do
      let(:user) { create(:user, :with_person, email: "user@example.com") }

      before do
        user.person.avatar.attach(
          io: Rails.root.join("spec/fixtures/files/sample.png").open,
          filename: "sample.png",
          content_type: "image/png"
        )
      end

      it "renders without touching the avatar" do
        expect(mail.body.encoded).to match("requested a password reset")
        expect(mail.body.encoded).not_to include("Avatar")
      end
    end
  end
end
