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
    bulk_payment: "Read from a bulk payment form, not the registration form.",
    payment: "Read from the event's registration form only; payment_method is also read on the bulk payment form."
  }.freeze

  GROUPS = [
    {
      key: :identity,
      title: "Who the registrant is",
      summary: "These decide which Person the submission belongs to. A logged-in respondent is always " \
               "their own account. Otherwise first name (or other first name), last name, and email are " \
               "matched against people on file, and the email can match any of the person's emails. No match creates a new person. Name and email are set " \
               "only on a new person — they never change someone already on file.",
      fields: [
        [ "first_name", "Preferred first name", "Sets a new person's first name — the name they go by. Never changes an existing person's name. Part of the match key." ],
        [ "legal_first_name", "Other first name", "Sets the person's legal first name, shown to admins on their profile, saved only when it differs from their first name. Used as a new person's first name when no first name is given. Also accepted in place of the first name when matching a returning person." ],
        [ "last_name", "Last name", "Sets a new person's last name; never changes an existing person's. Part of the match key — without it no person can be matched or created." ],
        [ "pronouns", "Pronouns", "Sets the person's pronouns." ],
        [ "pronunciation", "Name pronunciation", "Sets the admin-only note on the person's profile for how to say their name." ],
        [ "primary_email", "Email", "Sets a new person's email, lowercased; never changes an existing person's. Part of the match key, compared against every email the person has, including their login." ],
        [ "primary_email_type", "Primary email type", "Sets whether the primary email is a work or personal address." ],
        [ "secondary_email", "Secondary email", "Sets the person's second email address." ],
        [ "secondary_email_type", "Secondary email type", "Sets whether the secondary email is a work or personal address." ],
        [ "confirm_email", "Confirm email", "Must match the Email answer exactly (capitalization counts) before the submission is accepted; skipped when left blank. Deliberately not stored as an answer — it is a typo check, not data." ]
      ]
    },
    {
      key: :person_profile,
      title: "The registrant's profile",
      summary: "Written straight onto the Person. A non-blank answer replaces what is on file — the " \
               "newest submission is treated as the freshest source — and a blank answer never " \
               "erases existing data. An answer that isn't one of the offered options is ignored. The " \
               "previous value stays in the record's audit trail.",
      fields: [
        [ "racial_ethnic_identity", "How would you best describe yourself?", "Sets the person's racial/ethnic identity." ],
        [ "anonymous_contributions", "How may we display the content you share?", "Sets whether the person's contributed content (reflections, quotes, artwork) is credited to them or shown anonymously. Also written from a survey delivered on a registration ticket callout." ],
        [ "display_name_preference", "Display my name as…", "Sets the name format the person's content is credited under (full name, first name and last initial, and so on). Also written from a survey delivered on a registration ticket callout." ]
      ]
    },
    {
      key: :profile_display,
      title: "The registrant's profile display",
      summary: "The same on/off switches as the Profile display preferences on the person's profile, " \
               "each asked as a Yes/No question named after the switch it sets. A Yes or No answer " \
               "replaces what is on file; an unanswered question leaves it alone. Also written from a " \
               "survey delivered on a registration ticket callout.",
      fields: FormBuilderService::PROFILE_VISIBILITY_QUESTIONS.map do |identifier, question|
        effect = if identifier == "profile_is_searchable"
          "Sets whether the person can be found in the people search."
        else
          "Sets the profile's \"#{Person::PROFILE_VISIBILITY_LABELS.fetch(identifier)}\" switch."
        end
        [ identifier, question, effect ]
      end
    },
    {
      key: :mailing_address,
      title: "The registrant's mailing address",
      summary: "Saves an address on the Person, but only when a city is answered. An address on file " \
               "with the same city, state, and street (spelling aside, or no street on one side) is updated " \
               "and made primary; otherwise a new primary address is added. Either way the old primary is " \
               "retired (made inactive).",
      fields: [
        [ "mailing_street", "Street address", "Sets the street of a new address, or fills a blank one on file. A street different from the one on file adds a new address." ],
        [ "mailing_city", "City", "Sets the city, and decides whether an address is saved at all — no city answered means no address." ],
        [ "mailing_state", "State / province", "Sets the state, and is matched with the city to find an address already on file. Required for a new address — a city answered without a state fails the submission." ],
        [ "mailing_zip", "Zip / postal code", "Sets the postal code." ],
        [ "mailing_country", "Country", "Sets the country. A blank answer never clears a country already on file; on a new address with a US state, it's set to United States." ],
        [ "mailing_address_type", "Address type", "Marks the address Work, Personal, or Mailing (Mailing also makes it the invoice address). Unanswered on a new address, it's stored as unknown. Any other option fails the submission." ]
      ]
    },
    {
      key: :phone,
      title: "The registrant's phone",
      summary: "Adds a phone contact method to the Person and makes it their primary, retiring any " \
               "previous primary phone. Re-submitting a number already on file (formatting aside) " \
               "reactivates it rather than duplicating it.",
      fields: [
        [ "phone", "Phone", "Saves the phone number as the person's primary phone contact." ],
        [ "phone_type", "Phone type", "Work marks the number a work phone. Anything else, including no answer, marks it personal — even a number already on file." ]
      ]
    },
    {
      key: :organization,
      title: "The registrant's organization",
      summary: "The organization name is looked up by exact name (ignoring capitalization) — a form never " \
               "creates an organization by itself. When it matches, the organization is linked to the " \
               "registration or submission, the answers below update its profile, and the person gets a " \
               "Job Affiliation from their position. A facilitator training registration or an agreement " \
               "form (on-demand, reinstatement) also gives them a Facilitator Affiliation, unless they " \
               "already hold a current one there. A submitted address goes on every current (active or " \
               "upcoming) affiliation the person holds at the organization; ended ones and other people's " \
               "keep theirs. When it doesn't match, nothing is written and an admin resolves it on the " \
               "Link organization page; linking applies the same rules, and with no address submitted, " \
               "fills affiliations that have none with the organization's address when it has exactly one. " \
               "See the \"What form answers change on people and organizations\" feature for the full list.",
      fields: [
        [ "organization_name", "Organization name", "Looked up against existing organizations by name, ignoring capitalization. A match is linked to the registration or submission; no match leaves it unlinked for an admin to resolve." ],
        [ "organization_position", "Position / title", "Creates a Job Affiliation between the person and that organization, titled with this answer, unless they already hold a current one with that title. Works the same on an event registration and a standalone form. A facilitator training (or an agreement form) adds a standing \"Facilitator\" affiliation alongside it." ],
        [ "organization_website", "Organization website", "Sets the organization's website, replacing what is on file, whether the form is submitted or an admin links it. An answer that isn't a web address is never saved and is listed as not applied. Note: a raw URL is saved exactly as entered, so it may not be clickable if it isn't a properly formed URL." ],
        [ "organization_type", "Organization type", "Sets the organization's type, replacing what is on file. An \"Other\" choice stores the typed text separately and adds it to the Other responses review queue." ],
        [ "organization_phone", "Organization phone", "Adds the number to the organization's phones as a work phone and makes it the primary; the old primary stays on the organization, just no longer primary. A number already on file (formatting aside) is reactivated rather than duplicated, and becomes primary only if the organization has no active primary." ],
        [ "organization_street", "Organization street address", "Decides which of the organization's addresses this is. Same street in the same city and state (or same street and ZIP) updates that address; a different street adds a new work address that becomes the organization's primary — the old primary stays, just no longer primary. Never rewrites the street on an address already on file, only fills a blank one." ],
        [ "organization_city", "Organization city", "Sets the city on a new address (fills a blank one on file), and decides whether an organization address is saved at all — no city answered means no address." ],
        [ "organization_state", "Organization state / province", "Sets the state on a new address (fills a blank one on file). Without it, no new address can be saved (an address requires a state), though an address already on file is still updated." ],
        [ "organization_zip", "Organization zip / postal code", "Sets the postal code, replacing the one on file. Also used to recognize an address already on file whose city is spelled differently." ],
        [ "organization_country", "Organization country", "Sets the country of the organization's work address, replacing the one on file." ]
      ]
    },
    {
      key: :tagging,
      title: "Sector and age group tagging",
      summary: "These answers are record ids, not text: the options come from Sector and Age range " \
               "records rather than from options typed into the form editor. The tags are applied to " \
               "the registrant only; an organization shows its active facilitators' primary tags. Submitting " \
               "both a primary and an additional selection overwrites the person's tags with the latest; " \
               "submitting only a primary reassigns it (the old primary stays as an additional tag), and " \
               "submitting only additional tags adds them, leaving the rest in place. Saved from event " \
               "registrations and standalone forms — not from ticket surveys or bulk payment forms.",
      fields: [
        [ "primary_sector", "Primary sector", "Tags the person with one primary sector. Offers no \"Other\" — a primary sector must be a real sector." ],
        [ "additional_sectors", "Additional sectors", "Tags the person with any number of additional sectors. An \"Other\" answer goes to the Other responses review queue, where it can be promoted into a real sector." ],
        [ "primary_age_group", "Primary age group served", "Tags the person with the primary age range served." ],
        [ "additional_age_groups", "Additional age groups served", "Tags the person with additional age ranges served." ]
      ]
    },
    {
      key: :payment,
      title: "Payment and paperwork",
      summary: "These record how the registrant expects to pay, whether someone else is covering it, " \
               "and which paperwork they asked for.",
      fields: [
        [ "payment_method", "Payment method", "Records how the registrant expects to pay. Choosing the pay-now credit card option sends them straight to a Stripe checkout for the balance due — not on scholarship applications or when nothing is owed. Hidden on free events. The option labels are tied to charge logic, so the form editor only lets you turn each one on or off." ],
        [ "someone_else_will_pay", "Will someone else be paying?", "Answering yes flags the registration as covered by a sponsor or partner; answering no clears it. Leaving it unanswered never clears an existing flag." ],
        [ "additional_forms", "Additional forms", "Checking Invoice or W-9 records that the registrant asked for it, and a resubmission that newly asks is noted. The digital ticket offers both on paid events either way. Labels match ignoring capitalization; unchecking never clears an earlier request." ]
      ]
    },
    {
      key: :quotes,
      title: "Quotes",
      summary: "Turns a submission's answers into a quote automatically. \"quote\" (or \"quote_body\") holds the " \
               "quote text; add \"quote_speaker_name\" and \"quote_age_range\" to capture who said it and their " \
               "age. On submission this becomes an unpublished Quote — credited to the speaker name, or " \
               "\"Anonymous\" when none is given — with the submitter's account (if they have one) as its creator " \
               "and the submission kept as the quote's source. Editing the submission updates the quote until " \
               "an admin edits or publishes it. An admin then reviews, refines, and publishes it from the " \
               "Quotes admin — nothing appears publicly until they do.",
      fields: [
        [ "quote", "Quote", "The quote text (simple, single-question forms). Saved as an unpublished Quote on submission, linked back to the submission. Review and publish it from the Quotes admin." ],
        [ "quote_body", "Quote text", "The quote text when the form splits the quote across questions. Takes precedence over \"quote\" if both are present." ],
        [ "quote_speaker_name", "Quote speaker name", "Who said the quote. Becomes the quote's credited speaker; with none given the quote credits \"Anonymous\"." ],
        [ "quote_age_range", "Quote speaker age", "The speaker's age or age range. Stored on the quote's age field." ]
      ]
    },
    {
      key: :consent,
      title: "Consent",
      summary: "Asks registrants to opt in to email communication. Any answer subscribes the person to " \
               "the News (mailing-list) topic, with the event or form recorded as its source — so offer only " \
               "a Yes option.",
      fields: [
        [ "communication_consent", "Email communication consent", "Any non-blank answer creates an active News topic subscription, sourced to this event or form, re-subscribing someone who had unsubscribed. Someone already subscribed is left as is." ]
      ]
    },
    {
      key: :continuing_education,
      title: "Continuing education",
      summary: "Answered on the event's continuing education form, asked as a section of its registration " \
               "page. Opting in creates the registrant's CE registration against a professional license, " \
               "with hours and cost taken from the event; without the opt-in the license questions are " \
               "ignored. Re-registering keeps the one CE registration and updates its license (a blank " \
               "answer keeps what's on file). Nothing changes once the CE certificate is issued.",
      fields: [
        [ "ce_credit_interest", "Do you seek CE hours?", "Answering yes creates the CE registration, once — re-registering with yes updates its license. Any other answer creates nothing and never removes CE already on file." ],
        [ "ce_license_number", "License number", "Picks the registrant's license by number and type — both must match, otherwise a new license is added. Left blank, the person's number-pending placeholder license is used (or created) so the CE registration still has something to hang on. A number entered later on the ticket's CE card replaces it." ],
        [ "ce_license_kind", "License type", "The license type, e.g. LCSW. With the number, it decides which license is used; a different type adds a separate license." ],
        [ "ce_license_issuing_state", "License issuing state", "Sets the state that issued the license." ],
        [ "ce_license_issuing_country", "License issuing country", "Sets the country that issued the license. Asked inside the issuing state's \"Not on list?\" box." ],
        [ "ce_license_expires_on", "License expiry", "Sets the license expiry date." ]
      ]
    },
    {
      key: :professional_license,
      title: "Professional license",
      summary: "Saves a professional license on the person's profile from a registration or standalone " \
               "form — any license, not only one used for CE. Nothing is enrolled in CE; that stays with " \
               "the ce_license_* questions on the event's continuing education form. A license is " \
               "identified by its number (plus type): the same license already on file is updated, a " \
               "number-pending placeholder is filled in, and otherwise a new license is added. No number " \
               "answered means no license is saved. Not saved from ticket callout surveys, bulk payment forms, " \
               "or anonymous submissions.",
      fields: [
        [ "license_number", "License number", "Finds or adds the person's license with this number. When the type is left blank, a recognized type typed in front of the number (\"LCSW 12345\" — LCSW, LMFT, LPCC, LEP, AMFT, ACSW, APCC) is moved into the type." ],
        [ "license_kind", "License type", "The license type, e.g. LCSW. The same number under another type is saved as a separate license. Left blank, the number matches a license on file under any type." ],
        [ "license_issuing_state", "License issuing state", "Sets the state that issued the license." ],
        [ "license_issuing_country", "License issuing country", "Sets the country that issued the license. Asked inside the issuing state's \"Not on list?\" box." ],
        [ "license_expires_on", "License expiry", "Sets the license expiry date." ]
      ]
    },
    {
      key: :bulk_payment,
      title: "Bulk payment",
      summary: "Answered on a bulk payment form, where one payer pays for several attendees. Nobody is " \
               "registered by it — admins match the listed attendees to registrants on the event's bulk " \
               "payments page. The payer comes from first_name, last_name, and primary_email (or their " \
               "login), but no other profile answers are saved; the organization name is only the " \
               "invoice's bill-to, never looked up or linked.",
      fields: [
        [ "bulk_payment_attendees", "Attendees", "The attendees being paid for. Listed on the invoice, the confirmation emails, and the ticket, and matched to registrants on the bulk payments page. Copied onto the payment record for card payments. Doesn't register anyone." ],
        [ "number_of_attendees", "Number of attendees", "How many attendees are being paid for; a card payment charges the event cost times this number (1 if unanswered). When unanswered, the invoice and the emailed total use the number of attendees listed instead." ]
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
  ].freeze

  # Endings that change how a question is asked, whatever comes before them.
  ENDINGS = [
    [ "…_state", "Asked as a US state / territory dropdown with a \"Not on list?\" box for typing any other province or state. One-line questions only." ],
    [ "…_country", "Asked as a country dropdown. When the form also asks the matching …_state question " \
                   "(mailing_state with mailing_country, say), it moves inside that question's \"Not on list?\" box, " \
                   "and picking a US state records the country as the United States. One-line questions only." ]
  ].freeze

  # Per-identifier note rendered under an answer-only chip, for values surfaced in
  # a chart or report worth pointing an admin to.
  ANSWER_ONLY_NOTES = {
    "referral_source" => "Its value is charted, under the question's own wording, in the breakdowns on the " \
                         "event roster, attendees (reports), and scholarship recipients pages, and listed on " \
                         "the form answers and form results pages.",
    "interested_in_more" => "Pre-selected Yes on the form. Does not subscribe anyone.",
    **%w[scholarship_eligibility scholarship_contribution impact_description implementation_plan additional_comments]
      .index_with { "Shown together as the person's scholarship application." }
  }.freeze

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

  def self.answer_only_note(identifier)
    ANSWER_ONLY_NOTES[identifier]
  end
end
