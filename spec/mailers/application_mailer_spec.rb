require 'rails_helper'

RSpec.describe ApplicationMailer do
  it 'wraps the configured programs mailbox in the AWBW Programs display name' do
    stub_email_config

    expect(described_class.sender).to eq(%("#{ApplicationMailer::FROM_NAME}" <#{EmailConfigHelpers::PROGRAMS_EMAIL}>))
  end

  it 'resolves the default from address when the mail is built, not when the class loads' do
    expect(described_class.default[:from]).to be_a(Proc)
    expect(described_class.default[:reply_to]).to be_a(Proc)
  end

  it 'uses the correct layout' do
    expect(described_class._layout).to eq('mailer')
  end
end
