module EmailConfigHelpers
  PROGRAMS_EMAIL = "umberto.programs@example.test".freeze
  NO_REPLY_EMAIL = "umberto.no-reply@example.test".freeze

  # PROGRAMS_EMAIL and NO_REPLY_EMAIL are unset in test, so `Organization.programs_email`
  # and `.no_reply_email` return nil and mail headers come out blank. Any example that
  # asserts on an address configures them here and asserts the configured value, so no
  # real mailbox is written into a spec.
  def stub_email_config(programs: PROGRAMS_EMAIL, no_reply: NO_REPLY_EMAIL)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("PROGRAMS_EMAIL").and_return(programs)
    allow(ENV).to receive(:[]).with("NO_REPLY_EMAIL").and_return(no_reply)
  end
end

RSpec.configure do |config|
  config.include EmailConfigHelpers
end
