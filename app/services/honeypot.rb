# Spam trap for the public, account-free forms. Every one of them renders a
# decoy input (see shared/_honeypot) that no human can reach — off-screen,
# zero-size, untabbable, and hidden from assistive tech — so anything arriving
# in it means an automated form-filler, and the submission is dropped silently
# rather than answered with an error a bot could learn from.
#
# It catches two kinds of bot:
#   1. One that fills our rendered form, including the hidden decoy → the decoy
#      arrives with a value.
#   2. One that POSTs a scraped or generic version of the form that never
#      included our decoy at all → the decoy key is missing. Because the partial
#      renders a plain text input, a real browser always submits the decoy key
#      (empty for humans), so a submission that omits it entirely did not come
#      from our form. This is the case that got past the value-only check.
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

  # `scope` is the param namespace the surrounding form posts under. Tripped when
  # the decoy carries a value, or when the decoy is absent — including a missing
  # scope — since our form always renders it and a real browser always submits it.
  def self.tripped?(params, scope)
    fields = params[scope]
    return true unless fields.respond_to?(:key?)
    fields[FIELD_NAME].present? || !fields.key?(FIELD_NAME)
  end
end
