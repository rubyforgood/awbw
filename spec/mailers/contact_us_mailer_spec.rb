require 'rails_helper'

RSpec.describe ContactUsMailer do
  describe '#hello' do
    it 'sends to the program email' do
      contact_params = {
        subject: 'Test Subject',
        from: 'test@example.com',
        q: 'adult',
        first_name: 'John',
        last_name: 'Doe',
        agency: 'Test Agency',
        message: 'This is a test message'
      }

      mail = described_class.hello(contact_params)

      expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
      expect(mail.subject).to eq('Test Subject')
      expect(mail.from).to eq([ 'test@example.com' ])
    end

    it 'defaults to the general program email when q is nil' do
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

    it 'renders the email content correctly' do
      contact_params = {
        subject: 'Test Subject',
        from: 'test@example.com',
        q: 'adult',
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
  end
end
