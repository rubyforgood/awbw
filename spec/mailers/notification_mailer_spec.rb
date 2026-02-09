require "rails_helper"

RSpec.describe NotificationMailer, type: :mailer do
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
    let(:story_idea) { create(:story_idea, created_by: user) }
    let(:notification) { create(:notification, kind: "idea_submitted_fyi", noticeable: story_idea) }

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
      it "renders without raising" do
        expect {
          described_class.idea_submitted_fyi(notification).deliver_now
        }.not_to raise_error
      end

      it "does not include Attachments section" do
        mail = described_class.idea_submitted_fyi(notification)
        expect(mail.body.encoded).not_to include("Attachments")
      end
    end
  end

  describe "#reset_password_fyi" do
    let(:user) { create(:user, email: "user@example.com") }
    let(:notification) { create(:notification, kind: "reset_password_fyi", noticeable: user) }
    let(:mail) { described_class.reset_password_fyi(notification) }

    subject(:mail) { described_class.reset_password_fyi(notification) }

    it "renders the headers" do
      expect(mail.subject).to include("AWBW portal:")
      expect(mail.subject).to include("password reset")
      expect(mail.subject).to include(notification.noticeable.name)
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
  end
end
