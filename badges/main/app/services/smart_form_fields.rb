# Catalog of the field identifiers that carry backend behavior, and what each one
# does when a submission arrives carrying it. Powers the "Smart form settings"
# reference page, which is the answer to the question the form editor's "Field
# identifier" box raises: what will typing this actually do?
#
# An ordinary question needs no identifier — its answer is stored on the form
# submission and nothing else happens. An identifier is what wires a question to
# a record: a Person column, an Organization address, a Stripe charge. This is the
# documentation of that wiring, kept next to the code so it can be tested against
# it rather than drifting into a stale wiki page.
#
# `effect` is written for an admin building a form, not for an engineer: say what
# happens to the data, not which service does it.
class SmartFormFields
  Field = Struct.new(:identifier, :question, :effect, keyword_init: true)
  Group = Struct.new(:key, :title, :summary, :fields, keyword_init: true)

  # Only "registration" forms run the registration pipeline; the CE and bulk
  # payment identifiers only do anything on a form attached to an event in that
  # role. Named here so the page can say so instead of implying every identifier
  # works everywhere.
  ROLE_NOTES = {
    continuing_education: "Read from the event's continuing education form, not the registration form.",
    bulk_payment: "Read from a bulk payment form, not the registration form."
  }.freeze

  GROUPS = [
    {
      key: :identity,
      title: "Who the registrant is",
      summary: "These decide which Person the submission belongs to. Email and last name plus either " \
               "the first name or the nickname are matched against existing people, so a returning " \
               "registrant updates their record instead of creating a duplicate.",
      fields: [
        [ "first_name", "First name", "Sets the person's first name. Part of the duplicate-match key. If a nickname is also answered, this becomes the legal first name instead." ],
        [ "last_name", "Last name", "Sets the person's last name. Part of the duplicate-match key — matching is skipped entirely when this is blank." ],
        [ "nickname", "Preferred nickname", "Becomes the person's first name, and the answer to First name moves to legal first name. Also accepted when matching a returning registrant, so someone who registered under their legal name is still recognized." ],
        [ "pronouns", "Pronouns", "Sets the person's pronouns when the person record is first created." ],
        [ "primary_email", "Email", "Sets the person's email, lowercased. Part of the duplicate-match key." ],
        [ "primary_email_type", "Primary email type", "Sets whether the primary email is a work or personal address." ],
        [ "secondary_email", "Secondary email", "Sets the person's second email address." ],
        [ "secondary_email_type", "Secondary email type", "Sets whether the secondary email is a work or personal address." ],
        [ "confirm_email", "Confirm email", "Checked against the primary email before the registration is accepted. Deliberately not stored as an answer — it is a typo check, not data." ]
      ]
    },
    {
      key: :person_profile,
      title: "The registrant's profile",
      summary: "Written straight onto the Person. A non-blank answer replaces what is on file — the " \
               "newest registration is treated as the freshest source — and a blank answer never " \
               "erases existing data. The previous value stays in the record's audit trail.",
      fields: [
        [ "racial_ethnic_identity", "How would you best describe yourself?", "Sets the person's racial/ethnic identity." ]
      ]
    },
    {
      key: :mailing_address,
      title: "The registrant's mailing address",
      summary: "Builds a personal address on the Person, but only when a city is answered. An existing " \
               "address in the same city and state is updated in place; otherwise a new primary address " \
               "is added and the old primary is retired.",
      fields: [
        [ "mailing_street", "Street address", "Sets the street of the mailing address." ],
        [ "mailing_city", "City", "Sets the city, and decides whether an address is saved at all — no city answered means no address." ],
        [ "mailing_state", "State / province", "Sets the state, and is matched with the city to find an address already on file." ],
        [ "mailing_zip", "Zip / postal code", "Sets the postal code." ],
        [ "mailing_country", "Country", "Sets the country. A blank answer never clears a country already on file." ],
        [ "mailing_address_type", "Address type", "Marks the address work or personal. Anything else is stored as unknown." ]
      ]
    },
    {
      key: :phone,
      title: "The registrant's phone",
      summary: "Adds a phone contact method to the Person and makes it their primary, retiring any " \
               "previous primary phone. Re-submitting a number already on file reactivates it rather " \
               "than duplicating it.",
      fields: [
        [ "phone", "Phone", "Saves the phone number as the person's primary phone contact." ],
        [ "phone_type", "Phone type", "Marks the number as a work phone; any other answer marks it personal." ]
      ]
    },
    {
      key: :organization,
      title: "The registrant's organization",
      summary: "The organization name is looked up by exact name — the registration never creates an " \
               "organization by itself. When it matches, the organization is linked to the registration, " \
               "the registrant gets a job affiliation and a facilitator affiliation, and the answers " \
               "below fill in the organization's profile. When it doesn't match, nothing is written and " \
               "an admin resolves it on the registration's Link organization page.",
      fields: [
        [ "agency_name", "Organization name", "Looked up against existing organizations by exact name. A match is linked to the registration; no match leaves the registration unlinked for an admin to resolve." ],
        [ "agency_position", "Position / title", "Becomes the job title on the registrant's affiliation with that organization." ],
        [ "agency_website", "Organization website", "Sets the organization's website. Replaces what is on file when the registrant submits it; when an admin links the organization by hand it only fills a blank, and a conflicting answer is flagged instead." ],
        [ "agency_type", "Organization type", "Sets the organization's type. An \"Other\" choice stores the typed text separately and adds it to the Other responses review queue." ],
        [ "agency_street", "Organization street address", "Sets the street of the organization's work address." ],
        [ "agency_city", "Organization city", "Sets the city, and decides whether an organization address is saved at all — no city answered means no address." ],
        [ "agency_state", "Organization state / province", "Sets the state. Without it, no new address can be saved (an address requires a state), though an address already on file is still updated." ],
        [ "agency_zip", "Organization zip / postal code", "Sets the postal code. Also used to recognize an address already on file whose city is spelled differently." ],
        [ "agency_country", "Organization country", "Sets the country of the organization's work address." ]
      ]
    },
    {
      key: :tagging,
      title: "Sector and age group tagging",
      summary: "These answers are record ids, not text: the options come from Sector and Age range " \
               "records rather than from options typed into the form editor. The tags are applied to " \
               "the registrant and to their linked organization.",
      fields: [
        [ "primary_sector_single", "Primary sector", "Tags the person and organization with one primary sector. Offers no \"Other\" — a primary sector must be a real sector." ],
        [ "additional_sectors", "Additional sectors", "Tags the person and organization with any number of additional sectors. An \"Other\" answer goes to the Other responses review queue, where it can be promoted into a real sector." ],
        [ "primary_age_group", "Primary age group(s) served", "Tags the person and organization with the primary age range served." ],
        [ "additional_age_group", "Additional age group(s) served", "Tags the person and organization with additional age ranges served." ],
        [ "primary_sector", "Additional sectors (legacy)", "Older name for the additional sectors question. Still honored so existing forms keep working; use additional_sectors on new forms." ],
        [ "primary_service_area", "Additional sectors (legacy)", "Older name for the additional sectors question. Still honored; use additional_sectors on new forms." ],
        [ "primary_service_area_single", "Primary sector (legacy)", "Older name for the primary sector question. Still honored; use primary_sector_single on new forms." ]
      ]
    },
    {
      key: :payment,
      title: "Payment and paperwork",
      summary: "These set the registration's expected payment and the paperwork the registrant sees on " \
               "their digital ticket.",
      fields: [
        [ "payment_method", "Payment method", "Records how the registrant expects to pay. Choosing the pay-now credit card option starts a Stripe checkout immediately, so this question's options are tied to charge logic and are shown read-only in the form editor." ],
        [ "someone_else_will_pay", "Will someone else be paying?", "Answering yes flags the registration as covered by a sponsor or partner. Leaving it unanswered never clears an existing flag." ],
        [ "additional_forms", "Additional forms", "Checking Invoice or W-9 turns on that download on the registrant's digital ticket. The option labels must match exactly." ]
      ]
    },
    {
      key: :consent,
      title: "Consent",
      summary: "Consent is opt-in and recorded once. An affirmative answer stamps the time and names the " \
               "event it came from. It is never cleared from here — withdrawal is a separate, deliberate " \
               "action — and a registrant who already consented is not re-stamped.",
      fields: [
        [ "communication_consent", "Email communication consent", "Any non-blank answer records mailing list consent, with the event as its source." ]
      ]
    },
    {
      key: :continuing_education,
      title: "Continuing education",
      summary: "Answered on the event's continuing education form. Opting in creates the registrant's CE " \
               "registration against a professional license, with hours and cost taken from the event.",
      fields: [
        [ "ce_credit_interest", "Do you seek CE hours?", "Answering yes creates the CE registration. Any other answer creates nothing." ],
        [ "ce_license_number", "License number", "Finds or creates the registrant's professional license. Left blank, a placeholder license is created so the CE registration still has something to hang on." ],
        [ "ce_license_kind", "License type", "Sets the license type, e.g. LCSW." ],
        [ "ce_license_issuing_state", "License issuing state", "Sets the state that issued the license." ],
        [ "ce_license_expires_on", "License expiry", "Sets the license expiry date." ]
      ]
    },
    {
      key: :bulk_payment,
      title: "Bulk payment",
      summary: "Answered on a bulk payment form, where one payer registers several attendees. These " \
               "drive the invoice, the confirmation email, and the Stripe charge metadata.",
      fields: [
        [ "bulk_payment_attendees", "Attendees", "The list of attendees being paid for. Read by the invoice, the confirmation email, and the payment record." ],
        [ "number_of_attendees", "Number of attendees", "The attendee count charged for. Falls back to the length of the attendee list when unanswered." ],
        [ "payer_email", "Payer email", "The payer's email, validated as an email address." ]
      ]
    }
  ].freeze

  # Identifiers seeded by the question library that carry no backend behavior:
  # their answers are stored on the form submission and read there. Listed so the
  # page can say so explicitly rather than leaving an admin to wonder whether a
  # missing identifier means "does nothing" or "not documented".
  ANSWER_ONLY_IDENTIFIERS = %w[
    referral_source training_motivation interested_in_more
    scholarship_eligibility scholarship_contribution impact_description
    implementation_plan additional_comments
    event_rating most_valuable improvement_suggestions
    payer_first_name payer_last_name payer_phone payer_organization
  ].freeze

  def self.groups
    GROUPS.map do |group|
      Group.new(
        key: group[:key],
        title: group[:title],
        summary: group[:summary],
        fields: group[:fields].map { |identifier, question, effect| Field.new(identifier:, question:, effect:) }
      )
    end
  end

  # Every documented identifier, for the drift spec and for a quick lookup.
  def self.identifiers
    GROUPS.flat_map { |group| group[:fields].map(&:first) }
  end

  def self.role_note(key)
    ROLE_NOTES[key]
  end
end
