require 'rails_helper'

RSpec.describe ApplicationMailer do
  it 'sets the default from address' do
    expect(described_class.default[:from]).to eq('noreply@awbw.org')
  end

  it 'uses the correct layout' do
    expect(described_class._layout).to eq('mailer')
  end
end