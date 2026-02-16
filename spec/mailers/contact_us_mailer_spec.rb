require 'rails_helper'

RSpec.describe ContactUsMailer do
  describe '#hello' do
    it 'sends to the program email' do
      contact_params = {
        subject: 'Test Subject',
        from: 'test@example.com',
        q: 'general',
        first_name: 'John',
        last_name: 'Doe',
        agency: 'Test Agency',
        message: 'This is a test message'
      }

      mail = described_class.hello(contact_params)

      expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
      expect(mail.subject).to eq('AWBW portal: New contact form submission from John Doe: Test Subject')
      expect(mail.from).to eq([ 'test@example.com' ])
    end

    it 'works when q is nil' do
      contact_params = {
        subject: 'Test Subject',
        from: 'test@example.com',
        q: nil,
        first_name: 'John',
        last_name: 'Doe',
        agency: 'Test Agency',
        message: 'This is a test message'
      }

      mail = described_class.hello(contact_params)

      expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
    end

    it 'renders the email content correctly for non-logged in user' do
      contact_params = {
        subject: 'Test Subject',
        from: 'test@example.com',
        q: 'general',
        first_name: 'John',
        last_name: 'Doe',
        agency: 'Test Agency',
        message: 'This is a test message'
      }

      mail = described_class.hello(contact_params)

      expect(mail.body.encoded).to include('John Doe')
      expect(mail.body.encoded).to include('This is a test message')
      expect(mail.body.encoded).to include('Test Agency')
    end

    it 'renders the email content correctly for logged in user' do
      user = create(:user, first_name: 'Jane', last_name: 'Smith')
      contact_params = {
        subject: 'Test Subject',
        from: user.email,
        q: 'general',
        first_name: user.first_name,
        last_name: user.last_name,
        agency: 'Test Agency',
        message: 'This is a test message from logged in user'
      }

      mail = described_class.hello(contact_params, user)

      expect(mail.body.encoded).to include('Jane Smith')
      expect(mail.body.encoded).to include('This is a test message from logged in user')
    end
  end
end
