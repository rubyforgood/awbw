require 'rails_helper'

RSpec.describe Notification do
  describe 'associations' do
    it { should belong_to(:noticeable) }
  end
end
