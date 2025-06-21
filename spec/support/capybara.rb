RSpec.configure do |config|
  # Configure default driver for system specs
  config.before(:each, type: :system) do
    driven_by :rack_test
  end
end