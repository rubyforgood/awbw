require 'rails_helper'

RSpec.describe ContactUsMailer do
  describe '#hello' do
    xit 'sends to the adult program email when q is "adult"' do
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

      expect(mail.to).to eq(['cturek@awbw.org'])
      expect(mail.subject).to eq('Test Subject')
      expect(mail.from).to eq(['test@example.com'])
    end

    xit 'sends to the children program email when q is "children"' do
      contact_params = {
        subject: 'Test Subject',
        from: 'test@example.com',
        q: 'children',
        first_name: 'John',
        last_name: 'Doe',
        agency: 'Test Agency',
        message: 'This is a test message'
      }

      mail = described_class.hello(contact_params)

      expect(mail.to).to eq(['cturekrials@awbw.org'])
    end

    xit 'sends to the general program email when q is "general"' do
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

      expect(mail.to).to eq(['programs@awbw.org'])
    end

    xit 'defaults to the general program email when q is nil' do
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

      expect(mail.to).to eq(['programs@awbw.org'])
    end

    xit 'renders the email content correctly' do
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