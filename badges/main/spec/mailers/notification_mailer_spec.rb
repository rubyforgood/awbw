require 'rails_helper'

RSpec.describe NotificationMailer do
  describe '#report_notification' do
    it 'renders successfully' do
      # Not sure if this mailer is actually never used, causing a bunch of errors, or the inky
      # extension is somehow working.
      pending 'The template for this mailer has an extension of inky'
      fail
    end
  end

  describe '#reset_password_notification' do
    xit 'renders the subject and sends to the correct email' do
      user = double('User', email: 'user@example.com')
      mail = described_class.reset_password_notification(user)

      expect(mail.subject).to eq('Reset Password Request')
      expect(mail.to).to eq(['programs@awbw.org'])
      expect(mail.from).to eq(['noreply@awbw.org'])
    end

    xit 'includes the user email in the email body' do
      user = double('User', email: 'user@example.com')
      mail = described_class.reset_password_notification(user)

      expect(mail.body.encoded).to include('user@example.com')
    end

    xit 'delivers the email' do
      user = double('User', email: 'user@example.com')
      mail = described_class.reset_password_notification(user)

      expect {
        mail.deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end