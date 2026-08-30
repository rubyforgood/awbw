# Spam trap for the public, account-free forms. Every one of them renders a
# decoy input (see shared/_honeypot) that no human can reach — off-screen,
# zero-size, untabbable, and hidden from assistive tech — so anything arriving
# in it means an automated form-filler, and the submission is dropped silently
# rather than answered with an error a bot could learn from.
#
# The name must be something these public forms never collect, or a genuine
# answer would read as spam — so not `website_url` (a real column on both
# Organization and Story) and not any FormField identifier. A person's LinkedIn
# is stored as `people.linked_in_url` and only ever edited on their profile, so
# it can't reach a public form. Kept as one constant so all four forms stay in
# step and a future collision is a one-line fix.
class Honeypot
  FIELD_NAME = "linkedin_profile".freeze

  # Only bots read this; it exists so the decoy looks like a real labelled field.
  LABEL = "LinkedIn profile".freeze

  # `scope` is the param namespace the surrounding form posts under.
  def self.tripped?(params, scope)
    params.dig(scope, FIELD_NAME).present?
  end
end
