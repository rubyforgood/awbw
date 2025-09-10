# frozen_string_literal: true

require "paperclip/matchers"

RSpec.configure do |config|
  config.include(Paperclip::Shoulda::Matchers)
end
