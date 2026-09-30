module EmailConfigHelpers
  PROGRAMS_EMAIL = "umberto.programs@example.test".freeze
  NO_REPLY_EMAIL = "umberto.no-reply@example.test".freeze

  # Overrides the suite-wide addresses below for one example — mainly to exercise the
  # REPLY_TO_EMAIL fallback, by passing the newer vars as nil.
  def stub_email_config(programs: PROGRAMS_EMAIL, no_reply: NO_REPLY_EMAIL)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("PROGRAMS_EMAIL").and_return(programs)
    allow(ENV).to receive(:[]).with("NO_REPLY_EMAIL").and_return(no_reply)
  end
end

# The suite runs configured, the way a deployment is: Notification#recipient_email is
# required, so every flow that emails staff would fail on a blank address. What happens
# when nothing is configured is asserted directly in spec/models/organization_spec.rb
# instead of being spread across the suite.
ENV["PROGRAMS_EMAIL"] ||= EmailConfigHelpers::PROGRAMS_EMAIL
ENV["NO_REPLY_EMAIL"] ||= EmailConfigHelpers::NO_REPLY_EMAIL

RSpec.configure do |config|
  config.include EmailConfigHelpers
end
