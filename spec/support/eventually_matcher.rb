RSpec::Matchers.define :eventually do |matcher|
  match do |block|
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until matcher.matches?(block.call)
    end
    true
  rescue Timeout::Error
    false
  end

  supports_block_expectations
end
