require 'rails_helper'

RSpec.describe ApplicationMailer do
  it 'sets the default from address with the AWBW Programs display name' do
    expect(described_class.default[:from]).to eq(described_class.sender)
    expect(described_class.default[:from]).to include(ApplicationMailer::FROM_NAME)
  end

  it 'uses the correct layout' do
    expect(described_class._layout).to eq('mailer')
  end
end
