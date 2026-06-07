# The default 2s wait is too tight for selenium + Turbo on loaded CI runners,
# causing intermittent failures where a Turbo redirect or debounced filter
# re-render lands just after the assertion times out. 5s removes that headroom
# without meaningfully slowing the suite (the wait only elapses on failure).
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
end
