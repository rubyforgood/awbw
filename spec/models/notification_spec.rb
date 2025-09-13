require 'rails_helper'

RSpec.describe Notification do

  describe 'associations' do
    it { should belong_to(:noticeable) }
  end

  describe 'enums' do
    it { should define_enum_for(:notification_type).with_values(created: 0, updated: 1) }
  end
end 