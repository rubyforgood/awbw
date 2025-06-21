RSpec.configure do |config|
  # Configure default driver for system specs
  config.before(:each, type: :system) do
    driven_by :rack_test
  end
  
  # Configure JavaScript driver for specs that need browser automation
  # Usage: it "test name", js: true do
  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
end