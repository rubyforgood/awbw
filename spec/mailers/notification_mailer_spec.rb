require 'rails_helper'

RSpec.describe NotificationMailer, type: :mailer do
  describe '#report_submitted_fyi' do
    it 'renders successfully' do
      # Not sure if this mailer is actually never used, causing a bunch of errors, or the inky
      # extension is somehow working.
      pending 'The template for this mailer has an extension of inky'
      fail
    end
  end

  describe '#password_reset_fyi' do
    let(:user) { create(:user, email: 'user@example.com') }
    let(:mail) { described_class.password_reset_fyi(user) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Reset Password Request')
      expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
      expect(mail.from).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
      expect(mail.reply_to).to eq([ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('Click the link below to reset your password')
      expect(mail.body.encoded).to match(user.reset_password_token)
    end

    it 'includes the user email in the email body' do
      expect(mail.body.encoded).to include('user@example.com')
    end

    it 'delivers the email' do
      expect {
        mail.deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
