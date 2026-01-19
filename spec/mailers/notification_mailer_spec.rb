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
