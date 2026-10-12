# The default 2s wait is too tight for selenium + Turbo on loaded CI runners,
# causing intermittent failures where a Turbo redirect or debounced filter
# re-render lands just after the assertion times out. 5s removes that headroom
# without meaningfully slowing the suite (the wait only elapses on failure).
Capybara.default_max_wait_time = 5

# Chrome reports a node detached mid-query (e.g. by a Turbo/Stimulus re-render) as
# an "unknown error"; re-raise it as a stale element so Capybara's waiting retries it.
module DetachedNodeIsStaleElement
  DETACHED_NODE_MESSAGE = "does not belong to the document".freeze

  def error
    ex = super
    return ex unless ex.is_a?(Selenium::WebDriver::Error::UnknownError) && ex.message.include?(DETACHED_NODE_MESSAGE)
    Selenium::WebDriver::Error::StaleElementReferenceError.new(ex.message)
  end
end
Selenium::WebDriver::Remote::Response.prepend(DetachedNodeIsStaleElement)

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
end
