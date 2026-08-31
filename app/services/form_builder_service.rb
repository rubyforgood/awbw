class FormBuilderService
  # Payment method options. The "pay now" option triggers an immediate Stripe
  # charge, so controllers match against PAYMENT_METHOD_PAY_NOW rather than
  # repeating its label. Keep this the single source of truth for the label.
  PAYMENT_METHOD_PAY_NOW = "Credit card (now)".freeze
  PAYMENT_METHOD_OPTIONS = [ PAYMENT_METHOD_PAY_NOW, "Credit card (later)", "Check" ].freeze

  # Post-event survey option sets. Likert agreement scale for the workshop-impact
  # questions; Yes/No/Other for the "was it clear?" questions (Other reveals a
  # specify box); a likelihood scale for the recipient survey.
  LIKERT_AGREEMENT_OPTIONS = [ "Strongly agree", "Agree", "Neutral", "Disagree", "Strongly disagree" ].freeze
  CLARITY_OPTIONS = [ "Yes", "No", "Other" ].freeze
  LIKELIHOOD_OPTIONS = [ "Very likely", "Likely", "Unsure", "Unlikely", "Very unlikely" ].freeze

  # The clarity radios fan out over the day's topics: link resources to them (in the
  # field editor) and the survey page renders one input per resource with the
  # resource title appended to this prompt.
  CLARITY_PROMPT = "Overall, was the information presented in a clear and concise manner for".freeze

  # The per-workshop growth questions fan out the same way — the workshop title lands
  # after the prompt. Shared with the seeder, which matches these fields by prompt.
  GROWTH_PERSONAL_PROMPT = "This workshop supported my <em>personal</em> growth:".freeze
  GROWTH_PROFESSIONAL_PROMPT = "This workshop supported my <em>professional</em> growth:".freeze

  SECTIONS = {
    person_identifier: { label: "Person identifier", method: :build_person_identifier_fields },
    person_contact_info: { label: "Person contact info", method: :build_person_contact_info_fields },
    person_background: { label: "Person background", method: :build_person_background_fields },
    professional_info: { label: "Professional info", method: :build_professional_info_fields },
    marketing: { label: "Marketing", method: :build_marketing_fields },
    continuing_education: { label: "Continuing education", method: :build_continuing_education_fields },
    scholarship: { label: "Scholarship", method: :build_scholarship_fields },
    payment: { label: "Payment", method: :build_payment_fields },
    consent: { label: "Consent", method: :build_consent_fields },
    post_event_feedback: { label: "Post-event feedback", method: :build_post_event_feedback_fields },
    day_1_survey: { label: "Day 1 survey", method: :build_day_1_survey_fields },
    day_2_survey: { label: "Day 2 survey", method: :build_day_2_survey_fields },
    recipient_survey: { label: "Scholarship recipient survey", method: :build_recipient_survey_fields },
    content_sharing_preferences: { label: "Content sharing preferences", method: :build_content_sharing_preferences_fields },
    bulk_payment: { label: "Bulk payment", method: :build_bulk_payment_fields }
  }.freeze

  def initialize(name:, sections:, role: nil)
    @name = name
    @sections = sections.map(&:to_sym)
    @role = role
  end

  def call
    form = Form.create!(
      name: @name,
      sections: @sections.map(&:to_s),
      role: @role
    )

    position = 0
    @sections.each do |key|
      section = SECTIONS.fetch(key)
      position = send(section[:method], form, position)
    end

    form
  end

  SECTION_FIELD_IDENTIFIERS = {
    person_identifier: %w[first_name last_name primary_email confirm_email],
    person_contact_info: %w[
      primary_email_type nickname pronouns secondary_email secondary_email_type
      mailing_street mailing_address_type mailing_city mailing_state mailing_zip mailing_country
      phone phone_type organization_name organization_position organization_website organization_type
      organization_street organization_city organization_state organization_zip organization_country
    ],
    person_background: %w[racial_ethnic_identity],
    professional_info: %w[primary_sector additional_sectors primary_age_group additional_age_groups],
    marketing: %w[referral_source training_motivation interested_in_more],
    continuing_education: %w[ce_credit_interest ce_license_number],
    scholarship: %w[scholarship_eligibility scholarship_contribution impact_description implementation_plan additional_comments],
    payment: %w[payment_method someone_else_will_pay],
    consent: %w[communication_consent],
    post_event_feedback: %w[event_rating most_valuable improvement_suggestions],
    # Every survey question is answer-only (stored on the form submission, not written
    # to any other record), so none carry an identifier. The seeder finds the fan-out
    # questions by their prompt text instead.
    day_1_survey: %w[],
    day_2_survey: %w[],
    recipient_survey: %w[],
    content_sharing_preferences: %w[anonymous_contributions display_name_preference],
    bulk_payment: %w[first_name last_name primary_email phone organization_name number_of_attendees payment_method bulk_payment_attendees]
  }.freeze

  # Header questions created by each section's builder method
  SECTION_HEADERS = {
    person_identifier: [],
    person_contact_info: [ "Contact Information", "Mailing Address", "Organization Information" ],
    person_background: [ "Background Information" ],
    professional_info: [ "Professional Information" ],
    marketing: [ "Marketing" ],
    continuing_education: [ "Continuing education" ],
    scholarship: [ "Scholarship Application", "Your goals", "Anything else?" ],
    payment: [ "Payment Information" ],
    consent: [ "Consent" ],
    post_event_feedback: [ "Post-Event Feedback" ],
    day_1_survey: [ "Day 1 evaluation" ],
    day_2_survey: [ "Day 2 evaluation" ],
    recipient_survey: [ "Post-training recipient questions" ],
    content_sharing_preferences: [ "Sharing preferences" ],
    bulk_payment: [ "Payer Information", "Payment Information", "Attendees" ]
  }.freeze

  # User-facing field labels each section's builder creates (questions only,
  # excluding group headers), in build order. Mirrors the build_* methods so the
  # new-form page can list a section's fields before the form exists. A spec
  # asserts this stays in sync with what the builders actually create.
  SECTION_FIELD_NAMES = {
    person_identifier: [ "First Name", "Last Name", "Email", "Confirm Email" ],
    person_contact_info: [
      "Primary Email Type", "Preferred Nickname", "Pronouns", "Secondary Email", "Secondary Email Type",
      "Street Address", "Address Type", "City", "State / Province", "Zip / Postal Code", "Country",
      "Phone", "Phone Type", "Organization Name", "Position / Title", "Organization Website", "Organization Type",
      "Organization Street Address", "Organization City", "Organization State / Province", "Organization Zip / Postal Code",
      "Organization Country"
    ],
    person_background: [ "How would you best describe yourself?" ],
    professional_info: [ "Primary sector", "Additional sectors", "Primary age group served", "Additional age groups served" ],
    marketing: [
      "How did you hear about this AWBW training?",
      "What motivated you to sign up for AWBW's Facilitator Training?",
      "Are you interested in learning more about upcoming trainings or resources?"
    ],
    continuing_education: [
      "Do you seek Continuing Education (CE) hours for this training?",
      "If seeking CE hours, what is your license type? (e.g. LMFT, LCSW, LPCC, LEP)",
      "What is your license number?",
      "In which state was your license issued?",
      "When does your license expire?"
    ],
    scholarship: [
      "I and/or my organization cannot afford the full training cost and need a scholarship to attend.",
      "How much are you (and/or your organization) able to pay for this training?",
      "How will what you gain from this training directly impact the people you serve?",
      "Please describe one way in which you plan to use art workshops and how you envision it will help.",
      "Anything else you'd like to share with us?"
    ],
    payment: [ "Payment method", "Will someone else be paying for your registration?" ],
    consent: [ "I agree to receive email communications from A Window Between Worlds." ],
    post_event_feedback: [ "How would you rate this event?", "What did you find most valuable?", "Any suggestions for improvement?" ],
    day_1_survey: [
      CLARITY_PROMPT, "Please elaborate.", CLARITY_PROMPT, "Please elaborate.",
      "This workshop supported my <em>personal</em> growth:",
      "This workshop supported my <em>professional</em> growth:",
      "The breakout rooms supported me in sharing about my experience and connect with other trainees.",
      "I was able to practice grounding and self-regulation during the training.",
      "What I learned today better prepared me to facilitate art workshops.",
      "What I learned today better prepared me to utilize trauma informed practices during art workshops.",
      "Taking time to review and reflect after each workshop on how an element of the arc of healing connected to a part of the workshop structure will support me in facilitating art workshops.",
      "Please tell us what aspects of day 1 of the training could be improved.",
      "Please tell us what aspects of day 1 you enjoyed the most.",
      "Imagine how you would share your experience of this training with someone who is considering attending. Please share in a couple of sentences what you would say or tell them.",
      "Comments"
    ],
    day_2_survey: [
      CLARITY_PROMPT, "Please elaborate.", CLARITY_PROMPT, "Please elaborate.",
      "This workshop supported my <em>personal</em> growth:",
      "This workshop supported my <em>professional</em> growth:",
      "The breakout rooms supported me in sharing about my experience and connect with other trainees.",
      "What I learned today better prepared me to facilitate art workshops that honor intersectionality.",
      "Having time to dive into topics related to questions and challenges helped me feel more prepared to facilitate art workshops.",
      "Taking time to review and reflect after each workshop on how an element of the arc of healing connected to a part of the workshop structure will support me in facilitating art workshops.",
      "To best prepare art workshop participants to create, I understand the importance of providing a warm-up before the creation portion of the art workshop.",
      "Please tell us what aspects of day 2 of the training could be improved.",
      "Please tell us what aspects of day 2 of the training you enjoyed the most.",
      "Would you like your name and email address included on a list we will share with your fellow trainees (for those who would like to stay in touch)?",
      "How can we better support your needs and those of your art workshop participants?",
      "Imagine how you would share your experience of this training with someone who is considering attending. Please share in a couple of sentences what you would say or tell them.",
      "Comments"
    ],
    recipient_survey: [
      "How did participating in this training impact you personally and/or professionally?",
      "What insights, tools, or facilitation skills from the training stood out most to you?",
      "What would have made the training more valuable for you?",
      "How likely are you to facilitate an AWBW art workshop in the next 3 months?",
      "Anything else you'd like us to know?"
    ],
    content_sharing_preferences: [
      "Display my name as…",
      "How may we display the content you share (reflections, quotes, artwork)?"
    ],
    bulk_payment: [
      "Payer first name", "Payer last name", "Payer email", "Phone", "Organization",
      "Payment method", "Number of attendees", "Attendees"
    ]
  }.freeze

  # Field labels a section's builder creates, for previewing a section's
  # contents before the form exists (used on the new-form page).
  def self.section_field_names(key)
    SECTION_FIELD_NAMES.fetch(key.to_sym, [])
  end

  # Maps each section to the `section` column value(s) its builder assigns to
  # fields, so fields can be grouped back to their section when reordering.
  # Several builders use a `group:` string that differs from the section key.
  SECTION_GROUPS = {
    person_identifier: %w[person_identifier],
    person_contact_info: %w[person_contact_info],
    person_background: %w[background],
    professional_info: %w[professional],
    marketing: %w[marketing],
    continuing_education: %w[continuing_education],
    scholarship: %w[scholarship],
    payment: %w[payment],
    consent: %w[consent],
    post_event_feedback: %w[post_event_feedback],
    day_1_survey: %w[day_1_survey],
    day_2_survey: %w[day_2_survey],
    recipient_survey: %w[recipient_survey],
    content_sharing_preferences: %w[content_sharing],
    bulk_payment: %w[bulk_payment]
  }.freeze

  # Built-in section keys that apply to a form with the given role. Scholarship
  # and bulk-payment forms show only their own section; every other role shows
  # all sections except those two.
  def self.applicable_section_keys(role)
    SECTIONS.keys.select do |key|
      case role
      when "scholarship" then key == :scholarship
      when "bulk_payment" then key == :bulk_payment
      when "continuing_education" then key == :continuing_education
      else key != :scholarship && key != :bulk_payment && key != :continuing_education
      end
    end
  end

  # Built-in section keys that currently have fields on the form. This — not the
  # stored `sections` column — is the source of truth for which sections are
  # present, so add/remove stays consistent with the edit-sections checkboxes
  # (which are rendered from the fields) even if the column drifts.
  def self.present_section_keys(form)
    group_to_key = SECTION_GROUPS.flat_map { |key, groups| groups.map { |group| [ group, key ] } }.to_h
    # pluck runs a fresh query rather than reading (and caching) the association,
    # so repeated calls within a single update see deletions made between them.
    form.form_fields.pluck(:section).filter_map { |section| group_to_key[section] }.uniq
  end

  # Ordered list of sections for the edit-sections page. Each entry is a hash
  # with a :kind of :builtin or :custom. Built-in sections carry their :label,
  # section :key, and :included state; custom (user-added) sections carry the
  # group_header :label and the :questions that follow it on the form.
  #
  # Sections present on the form are ordered by their position there, so a
  # custom section slots into the list wherever it sits on the form. Built-in
  # sections not currently on the form follow their canonical predecessor.
  def self.editable_sections(form)
    group_to_key = SECTION_GROUPS.flat_map { |key, groups| groups.map { |group| [ group, key ] } }.to_h

    positions = {}
    header_names = {}
    questions = Hash.new { |hash, key| hash[key] = [] }
    customs = []
    current = nil

    # Rank by iteration order rather than the stored position, which is nullable
    # and can collide, so the sort keys below are always comparable integers.
    form.form_fields.reorder(position: :asc).each_with_index do |field, order|
      key = group_to_key[field.section]
      if key
        current = nil
        positions[key] ||= order
        if field.group_header?
          header_names[key] ||= field.name
        else
          questions[key] << field
        end
      elsif field.group_header?
        current = { kind: :custom, header: field, questions: [] }
        customs << [ order, current ]
      elsif current
        current[:questions] << field
      end
    end

    entries = []
    last_position = 0
    applicable_section_keys(form.role).each_with_index do |key, rank|
      position = positions[key]
      last_position = position if position
      default_header = SECTION_HEADERS.fetch(key).first
      header_name = header_names[key]
      entries << {
        sort: [ position || last_position, position ? 0 : 1, rank ],
        kind: :builtin,
        key: key,
        label: SECTIONS.fetch(key)[:label],
        included: !position.nil?,
        questions: questions[key],
        renamed_header: (header_name if header_name.present? && header_name != default_header)
      }
    end

    customs.each do |position, custom|
      entries << custom.merge(sort: [ position, 0, 0 ], label: custom[:header].name)
    end

    entries.sort_by { |entry| entry[:sort] }
  end

  # Update sections on an existing form: add new sections, remove unchecked ones.
  # remove_custom_section_ids are group_header field ids of custom sections the
  # user unchecked; each such header and the questions under it are deleted.
  def self.update_sections!(form, new_sections, remove_custom_section_ids: [])
    new_sections = new_sections.map(&:to_sym)
    old_sections = present_section_keys(form)

    remove_custom_sections!(form, remove_custom_section_ids)

    added = new_sections - old_sections
    removed = old_sections - new_sections

    # Remove every field belonging to a removed section by its section group.
    # Keying off the group (not the canonical field_identifier or default header
    # name) deletes renamed headers too, so nothing is left orphaned to resurface
    # as a duplicate when the section is added back.
    removed.each do |key|
      form.form_fields.where(section: SECTION_GROUPS.fetch(key)).destroy_all
    end

    # Build fields for newly checked sections (created at the end for now), then
    # renumber everything so sections follow the edit-sections page order.
    if added.any?
      max_position = form.form_fields.maximum(:position) || 0
      builder = new(name: form.name, sections: added)
      added.each do |key|
        section = SECTIONS.fetch(key)
        max_position = builder.send(section[:method], form, max_position)
      end
      reorder_to_page_order!(form, new_sections)
    end

    form.update!(sections: new_sections.map(&:to_s))
    form
  end

  # Delete the given custom sections — each group_header field plus the questions
  # that follow it on the form — identified by their header field ids.
  def self.remove_custom_sections!(form, header_ids)
    header_ids = Array(header_ids).map(&:to_i)
    return if header_ids.empty?

    targets = editable_sections(form).select do |entry|
      entry[:kind] == :custom && header_ids.include?(entry[:header].id)
    end
    field_ids = targets.flat_map { |entry| [ entry[:header].id, *entry[:questions].map(&:id) ] }
    form.form_fields.where(id: field_ids).destroy_all if field_ids.any?
  end

  # Renumber a form's fields so sections appear in the canonical page order
  # (the order of SECTIONS / the edit-sections checkboxes), preserving each
  # field's existing order within its own section.
  def self.reorder_to_page_order!(form, section_order)
    section_for_group = SECTION_GROUPS.flat_map { |key, groups| groups.map { |group| [ group, key ] } }.to_h
    rank = SECTIONS.keys.select { |key| section_order.include?(key) }.each_with_index.to_h

    ordered = form.form_fields.reorder(:position).to_a.each_with_index.sort_by do |field, index|
      section_key = section_for_group[field.section]
      [ rank.fetch(section_key, rank.size), index ]
    end

    ordered.each_with_index do |(field, _index), position|
      new_position = position + 1
      field.update_column(:position, new_position) unless field.position == new_position
    end
  end

  private

  SECTION_VISIBILITY = {
    "person_identifier" => :logged_out_only,
    "person_contact_info" => :logged_out_only,
    "background" => :logged_out_only,
    "professional" => :answers_on_file,
    "marketing" => :answers_on_file,
    "continuing_education" => :always_ask,
    "payment" => :always_ask,
    "scholarship" => :always_ask,
    "consent" => :answers_on_file,
    "post_event_feedback" => :answers_on_file,
    "bulk_payment" => :always_ask
  }.freeze

  # Sections where answers carry across all events (ask once ever)
  ONE_TIME_SECTIONS = %w[professional background].freeze

  def add_header(form, position, title, group:, visibility: nil)
    position += 1
    form.form_fields.create!(
      name: title,
      answer_type: :group_header,
      status: :active,
      position: position,
      required: false,
      field_identifier: nil,
      section: group,
      visibility: visibility || SECTION_VISIBILITY.fetch(group, :always_ask),
      one_time: ONE_TIME_SECTIONS.include?(group)
    )
    position
  end

  def add_field(form, position, field_name, answer_type, group:, key: nil, required: true, subtitle: nil, options: nil, datatype: nil, visibility: nil, width: :full)
    position += 1
    field = form.form_fields.create!(
      name: field_name,
      answer_type: answer_type,
      input_type: datatype,
      status: :active,
      position: position,
      required: required,
      subtitle: subtitle,
      field_identifier: key,
      section: group,
      visibility: visibility || SECTION_VISIBILITY.fetch(group, :always_ask),
      one_time: ONE_TIME_SECTIONS.include?(group),
      width: width
    )

    if options.present?
      options.each_with_index do |opt, idx|
        ao = AnswerOption.find_or_create_by!(name: opt) do |a|
          a.position = idx
        end
        field.form_field_answer_options.create!(answer_option: ao)
      end
    end

    position
  end

  # ---- Section builders ----

  def build_person_identifier_fields(form, position)
    position = add_field(form, position, "First Name", :free_form_input_one_line,
                         key: "first_name", group: "person_identifier", required: true, width: :half)
    position = add_field(form, position, "Last Name", :free_form_input_one_line,
                         key: "last_name", group: "person_identifier", required: true, width: :half)
    position = add_field(form, position, "Email", :free_form_input_one_line,
                         key: "primary_email", group: "person_identifier", required: true, width: :half)
    position = add_field(form, position, "Confirm Email", :free_form_input_one_line,
                         key: "confirm_email", group: "person_identifier", required: true, width: :half)
    position
  end

  def build_person_contact_info_fields(form, position)
    position = add_header(form, position, "Contact Information", group: "person_contact_info")

    position = add_field(form, position, "Primary Email Type", :single_select_radio,
                         key: "primary_email_type", group: "person_contact_info", required: true,
                         options: %w[Personal Work])
    position = add_field(form, position, "Preferred Nickname", :free_form_input_one_line,
                         key: "nickname", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Pronouns", :free_form_input_one_line,
                         key: "pronouns", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Secondary Email", :free_form_input_one_line,
                         key: "secondary_email", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Secondary Email Type", :single_select_radio,
                         key: "secondary_email_type", group: "person_contact_info", required: false,
                         width: :half, options: %w[Personal Work])

    position = add_header(form, position, "Mailing Address", group: "person_contact_info")
    position = add_field(form, position, "Street Address", :free_form_input_one_line,
                         key: "mailing_street", group: "person_contact_info", required: true, width: :half)
    position = add_field(form, position, "Address Type", :single_select_radio,
                         key: "mailing_address_type", group: "person_contact_info", required: true,
                         width: :half, options: %w[Work Personal])
    position = add_field(form, position, "City", :free_form_input_one_line,
                         key: "mailing_city", group: "person_contact_info", required: true, width: :third)
    position = add_field(form, position, "State / Province", :free_form_input_one_line,
                         key: "mailing_state", group: "person_contact_info", required: true, width: :third)
    position = add_field(form, position, "Zip / Postal Code", :free_form_input_one_line,
                         key: "mailing_zip", group: "person_contact_info", required: true, width: :third)
    position = add_field(form, position, "Country", :free_form_input_one_line,
                         key: "mailing_country", group: "person_contact_info", required: false)

    position = add_field(form, position, "Phone", :free_form_input_one_line,
                         key: "phone", group: "person_contact_info", required: true, width: :half)
    position = add_field(form, position, "Phone Type", :single_select_radio,
                        key: "phone_type", group: "person_contact_info", required: true,
                        width: :half, options: %w[Work Personal])

    position = add_header(form, position, "Organization Information", group: "person_contact_info")
    position = add_field(form, position, "Organization Name", :free_form_input_one_line,
                         key: "organization_name", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Position / Title", :free_form_input_one_line,
                         key: "organization_position", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Organization Website", :free_form_input_one_line,
                         key: "organization_website", group: "person_contact_info", required: false)
    position = add_field(form, position, "Organization Type", :single_select_radio,
                         key: "organization_type", group: "person_contact_info", required: false,
                         options: Organization::ORGANIZATION_TYPES)
    position = add_field(form, position, "Organization Street Address", :free_form_input_one_line,
                         key: "organization_street", group: "person_contact_info", required: false)
    position = add_field(form, position, "Organization City", :free_form_input_one_line,
                         key: "organization_city", group: "person_contact_info", required: false, width: :third)
    position = add_field(form, position, "Organization State / Province", :free_form_input_one_line,
                         key: "organization_state", group: "person_contact_info", required: false, width: :third)
    position = add_field(form, position, "Organization Zip / Postal Code", :free_form_input_one_line,
                         key: "organization_zip", group: "person_contact_info", required: false, width: :third)
    position = add_field(form, position, "Organization Country", :free_form_input_one_line,
                         key: "organization_country", group: "person_contact_info", required: false)
    position
  end

  # Self-identified race/ethnicity options, mirroring the AWBW facilitator
  # training form. Stored under the long-standing racial_ethnic_identity
  # identifier so existing reporting keeps resolving.
  RACIAL_ETHNIC_IDENTITY_OPTIONS = [
    "Alaskan Native", "American Indian or Native American", "Asian",
    "Black or African American", "Latinx", "Middle Eastern", "Multi-racial",
    "Native Hawaiian or other Pacific Islander", "White"
  ].freeze

  def build_person_background_fields(form, position)
    position = add_header(form, position, "Background Information", group: "background")

    position = add_field(form, position, "How would you best describe yourself?", :single_select_radio,
                         key: "racial_ethnic_identity", group: "background", required: false,
                         options: RACIAL_ETHNIC_IDENTITY_OPTIONS)
    position
  end

  def build_professional_info_fields(form, position)
    position = add_header(form, position, "Professional Information", group: "professional")

    position = add_field(form, position, "Primary sector", :single_select_dropdown,
                         key: "primary_sector", group: "professional", required: false,
                         subtitle: "Select the option that best represents those you primarily intend to serve through the art workshops")
    position = add_field(form, position, "Additional sectors", :multi_select_checkbox,
                         key: "additional_sectors", group: "professional", required: false,
                         subtitle: "Select all options that represent who you intend to serve through the art workshops (check all that apply)")
    position = add_field(form, position, "Primary age group served", :single_select_dropdown,
                         key: "primary_age_group", group: "professional", required: false,
                         subtitle: "Select the age group you primarily intend to serve through the art workshops")
    position = add_field(form, position, "Additional age groups served", :multi_select_checkbox,
                         key: "additional_age_groups", group: "professional", required: false,
                         subtitle: "Select all additional age groups you may serve through the art workshops (check all that apply)")
    position
  end

  # Ways a registrant may have heard about the training. Several options reveal a
  # free-text "please specify" box (see FormField::SPECIFY_OPTION_PLACEHOLDERS).
  REFERRAL_SOURCE_OPTIONS = [
    "Online Search", "Social Media", "Presentation",
    "Work(ed) at an agency that has/had an AWBW program", "Word of Mouth",
    "Foundation/Funder", "Email from AWBW", "Other"
  ].freeze

  # What motivated a registrant to sign up, mirroring the AWBW facilitator
  # training form. Multi-select; the trailing "Other" reveals a free-text box.
  TRAINING_MOTIVATION_OPTIONS = [
    "Use art to offer accessible and effective client programming (strength-based, low-barrier, research-informed)",
    "Deepen understanding of trauma-informed and intersectional practices",
    "Address staff burnout through art",
    "Support staff wellness through art",
    "Connect with and learn from a community of art facilitators",
    "Use art for team building and organizational culture change",
    "Use art to support advocacy, awareness, and/or fundraising",
    "Earn certification as an AWBW Facilitator for personal/professional development",
    "Earn Continuing Education (CE) hours and expand knowledge about integrating art into clinical work",
    "Other"
  ].freeze

  def build_marketing_fields(form, position)
    position = add_header(form, position, "Marketing", group: "marketing")

    position = add_field(form, position, "How did you hear about this AWBW training?", :single_select_radio,
                         key: "referral_source", group: "marketing", required: false,
                         options: REFERRAL_SOURCE_OPTIONS)
    position = add_field(form, position, "What motivated you to sign up for AWBW's Facilitator Training?",
                         :multi_select_checkbox,
                         key: "training_motivation", group: "marketing", required: false,
                         options: TRAINING_MOTIVATION_OPTIONS)
    position = add_field(form, position, "Are you interested in learning more about upcoming trainings or resources?",
                         :single_select_radio,
                         key: "interested_in_more", group: "marketing", required: true,
                         options: %w[Yes No])
    position
  end

  def build_continuing_education_fields(form, position)
    position = add_header(form, position, "Continuing education", group: "continuing_education")

    position = add_field(form, position,
                         "Do you seek Continuing Education (CE) hours for this training?",
                         :single_select_radio,
                         key: "ce_credit_interest", group: "continuing_education", required: true,
                         options: %w[Yes No])
    position = add_field(form, position,
                         "If seeking CE hours, what is your license type? (e.g. LMFT, LCSW, LPCC, LEP)",
                         :free_form_input_one_line,
                         key: "ce_license_kind", group: "continuing_education", required: false,
                         subtitle: "These license details are optional here — you can add or update them later " \
                                   "from your registration ticket.")
    position = add_field(form, position,
                         "What is your license number?",
                         :free_form_input_one_line,
                         key: "ce_license_number", group: "continuing_education", required: false,
                         subtitle: "Acceptance of continuing education hours is determined by each individual state board separately, " \
                                   "and AWBW cannot guarantee your specific state board will accept them. " \
                                   "Participants are responsible for confirming whether the hours meet the requirements " \
                                   "for their specific license and state.")
    position = add_field(form, position,
                         "In which state was your license issued?",
                         :free_form_input_one_line,
                         key: "ce_license_issuing_state", group: "continuing_education", required: false)
    position = add_field(form, position,
                         "When does your license expire?",
                         :free_form_input_one_line,
                         key: "ce_license_expires_on", group: "continuing_education", required: false,
                         datatype: :date)
    position
  end

  def build_scholarship_fields(form, position)
    position = add_header(form, position, "Scholarship Application", group: "scholarship")

    position = add_field(form, position,
                         "I and/or my organization cannot afford the full training cost and need a scholarship to attend.",
                         :single_select_radio,
                         key: "scholarship_eligibility", group: "scholarship", required: true,
                         options: %w[Yes No])
    position = add_field(form, position,
                         "How much are you (and/or your organization) able to pay for this training?",
                         :free_form_input_one_line,
                         key: "scholarship_contribution", group: "scholarship", required: false)

    position = add_header(form, position, "Your goals", group: "scholarship")
    position = add_field(form, position,
                         "How will what you gain from this training directly impact the people you serve?",
                         :free_form_input_paragraph,
                         key: "impact_description", group: "scholarship", required: true,
                         subtitle: "Please describe in 3-5+ sentences.")
    position = add_field(form, position,
                         "Please describe one way in which you plan to use art workshops and how you envision it will help.",
                         :free_form_input_paragraph,
                         key: "implementation_plan", group: "scholarship", required: true,
                         subtitle: "Please describe in 3-5+ sentences.")

    position = add_header(form, position, "Anything else?", group: "scholarship")
    position = add_field(form, position, "Anything else you'd like to share with us?", :free_form_input_paragraph,
                         key: "additional_comments", group: "scholarship", required: false)
    position
  end

  def build_payment_fields(form, position)
    position = add_header(form, position, "Payment Information", group: "payment")

    position = add_field(form, position, "Payment method", :single_select_radio,
                         key: "payment_method", group: "payment", required: true,
                         options: PAYMENT_METHOD_OPTIONS)
    position = add_field(form, position, "Will someone else be paying for your registration?", :single_select_radio,
                         key: "someone_else_will_pay", group: "payment", required: true,
                         subtitle: "Choose \"Yes\" if a sponsor, partner, or organization will be covering your cost.",
                         options: %w[Yes No])
    position
  end

  def build_consent_fields(form, position)
    position = add_header(form, position, "Consent", group: "consent")
    position = add_field(form, position,
                         "I agree to receive email communications from A Window Between Worlds.",
                         :multi_select_checkbox,
                         key: "communication_consent", group: "consent", required: true,
                         subtitle: "By submitting this form, I consent to receive updates from A Window Between Worlds, " \
                               "including information about this event as well as upcoming events, training opportunities, resources, " \
                               "impact stories, and ways to support our mission. I understand I can unsubscribe at any time.",
                         options: [ "Yes" ])
    position
  end

  def build_post_event_feedback_fields(form, position)
    position = add_header(form, position, "Post-Event Feedback", group: "post_event_feedback")

    position = add_field(form, position, "How would you rate this event?", :single_select_radio,
                         key: "event_rating", group: "post_event_feedback", required: true,
                         options: [ "Excellent", "Good", "Fair", "Poor" ])
    position = add_field(form, position, "What did you find most valuable?", :free_form_input_paragraph,
                         key: "most_valuable", group: "post_event_feedback", required: false)
    position = add_field(form, position, "Any suggestions for improvement?", :free_form_input_paragraph,
                         key: "improvement_suggestions", group: "post_event_feedback", required: false)
    position
  end

  def build_day_1_survey_fields(form, position)
    position = add_header(form, position, "Day 1 evaluation", group: "day_1_survey")

    position = add_field(form, position, CLARITY_PROMPT, :single_select_radio,
                         group: "day_1_survey", subtitle: "Day 1 — Part One",
                         options: CLARITY_OPTIONS)
    position = add_field(form, position, "Please elaborate.", :free_form_input_paragraph,
                         group: "day_1_survey", required: false)
    position = add_field(form, position, CLARITY_PROMPT, :single_select_radio,
                         group: "day_1_survey", subtitle: "Day 1 — Part Two",
                         options: CLARITY_OPTIONS)
    position = add_field(form, position, "Please elaborate.", :free_form_input_paragraph,
                         group: "day_1_survey", required: false)

    # Fanned per workshop (seeded resource links) — the workshop name lands after
    # the prompt, so the text stays generic.
    position = add_field(form, position, GROWTH_PERSONAL_PROMPT, :single_select_radio,
                         group: "day_1_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, GROWTH_PROFESSIONAL_PROMPT, :single_select_radio,
                         group: "day_1_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "The breakout rooms supported me in sharing about my experience and connect with other trainees.", :single_select_radio,
                         group: "day_1_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "I was able to practice grounding and self-regulation during the training.", :single_select_radio,
                         group: "day_1_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "What I learned today better prepared me to facilitate art workshops.", :single_select_radio,
                         group: "day_1_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "What I learned today better prepared me to utilize trauma informed practices during art workshops.", :single_select_radio,
                         group: "day_1_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "Taking time to review and reflect after each workshop on how an element of the arc of healing connected to a part of the workshop structure will support me in facilitating art workshops.", :single_select_radio,
                         group: "day_1_survey", options: LIKERT_AGREEMENT_OPTIONS)

    position = add_field(form, position, "Please tell us what aspects of day 1 of the training could be improved.", :free_form_input_paragraph,
                         group: "day_1_survey", required: false)
    position = add_field(form, position, "Please tell us what aspects of day 1 you enjoyed the most.", :free_form_input_paragraph,
                         group: "day_1_survey", required: false)
    position = add_field(form, position, "Imagine how you would share your experience of this training with someone who is considering attending. Please share in a couple of sentences what you would say or tell them.", :free_form_input_paragraph,
                         group: "day_1_survey", required: false)
    position = add_field(form, position, "Comments", :free_form_input_paragraph,
                         group: "day_1_survey", required: false)
    position
  end

  def build_day_2_survey_fields(form, position)
    position = add_header(form, position, "Day 2 evaluation", group: "day_2_survey")

    position = add_field(form, position, CLARITY_PROMPT, :single_select_radio,
                         group: "day_2_survey", subtitle: "Day 2 — Part 1",
                         options: CLARITY_OPTIONS)
    position = add_field(form, position, "Please elaborate.", :free_form_input_paragraph,
                         group: "day_2_survey", required: false)
    position = add_field(form, position, CLARITY_PROMPT, :single_select_radio,
                         group: "day_2_survey", subtitle: "Day 2 — Part 2",
                         options: CLARITY_OPTIONS)
    position = add_field(form, position, "Please elaborate.", :free_form_input_paragraph,
                         group: "day_2_survey", required: false)

    # Fanned per workshop (seeded resource links) — the workshop name lands after
    # the prompt, so the text stays generic.
    position = add_field(form, position, GROWTH_PERSONAL_PROMPT, :single_select_radio,
                         group: "day_2_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, GROWTH_PROFESSIONAL_PROMPT, :single_select_radio,
                         group: "day_2_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "The breakout rooms supported me in sharing about my experience and connect with other trainees.", :single_select_radio,
                         group: "day_2_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "What I learned today better prepared me to facilitate art workshops that honor intersectionality.", :single_select_radio,
                         group: "day_2_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "Having time to dive into topics related to questions and challenges helped me feel more prepared to facilitate art workshops.", :single_select_radio,
                         group: "day_2_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "Taking time to review and reflect after each workshop on how an element of the arc of healing connected to a part of the workshop structure will support me in facilitating art workshops.", :single_select_radio,
                         group: "day_2_survey", options: LIKERT_AGREEMENT_OPTIONS)
    position = add_field(form, position, "To best prepare art workshop participants to create, I understand the importance of providing a warm-up before the creation portion of the art workshop.", :single_select_radio,
                         group: "day_2_survey", options: LIKERT_AGREEMENT_OPTIONS)

    position = add_field(form, position, "Please tell us what aspects of day 2 of the training could be improved.", :free_form_input_paragraph,
                         group: "day_2_survey", required: false)
    position = add_field(form, position, "Please tell us what aspects of day 2 of the training you enjoyed the most.", :free_form_input_paragraph,
                         group: "day_2_survey", required: false)
    position = add_field(form, position, "Would you like your name and email address included on a list we will share with your fellow trainees (for those who would like to stay in touch)?", :single_select_radio,
                         group: "day_2_survey", required: false, options: %w[Yes No])
    position = add_field(form, position, "How can we better support your needs and those of your art workshop participants?", :free_form_input_paragraph,
                         group: "day_2_survey", required: false)
    position = add_field(form, position, "Imagine how you would share your experience of this training with someone who is considering attending. Please share in a couple of sentences what you would say or tell them.", :free_form_input_paragraph,
                         group: "day_2_survey", required: false)
    position = add_field(form, position, "Comments", :free_form_input_paragraph,
                         group: "day_2_survey", required: false)
    position
  end

  def build_recipient_survey_fields(form, position)
    position = add_header(form, position, "Post-training recipient questions", group: "recipient_survey")

    position = add_field(form, position, "How did participating in this training impact you personally and/or professionally?", :free_form_input_paragraph,
                         group: "recipient_survey", required: true)
    position = add_field(form, position, "What insights, tools, or facilitation skills from the training stood out most to you?", :free_form_input_paragraph,
                         group: "recipient_survey", required: true)
    position = add_field(form, position, "What would have made the training more valuable for you?", :free_form_input_paragraph,
                         group: "recipient_survey", required: false)
    position = add_field(form, position, "How likely are you to facilitate an AWBW art workshop in the next 3 months?", :single_select_radio,
                         group: "recipient_survey", options: LIKELIHOOD_OPTIONS)
    position = add_field(form, position, "Anything else you'd like us to know?", :free_form_input_paragraph,
                         group: "recipient_survey", required: false)
    position
  end

  def build_content_sharing_preferences_fields(form, position)
    position = add_header(form, position, "Sharing preferences", group: "content_sharing")

    position = add_field(form, position, "Display my name as…", :single_select_radio,
                         key: "display_name_preference", group: "content_sharing",
                         options: Person::DISPLAY_NAME_PREFERENCE_LABELS.values)
    position = add_field(form, position, "How may we display the content you share (reflections, quotes, artwork)?", :single_select_radio,
                         key: "anonymous_contributions", group: "content_sharing",
                         options: Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS.values)
    position
  end

  def build_bulk_payment_fields(form, position)
    position = add_header(form, position, "Payer Information", group: "bulk_payment", visibility: :logged_out_only)

    position = add_field(form, position, "Payer first name", :free_form_input_one_line,
                         key: "first_name", group: "bulk_payment", required: true,
                         width: :half, visibility: :logged_out_only)
    position = add_field(form, position, "Payer last name", :free_form_input_one_line,
                         key: "last_name", group: "bulk_payment", required: true,
                         width: :half, visibility: :logged_out_only)
    position = add_field(form, position, "Payer email", :free_form_input_one_line,
                         key: "primary_email", group: "bulk_payment", required: true,
                         width: :half, visibility: :logged_out_only)
    position = add_field(form, position, "Phone", :free_form_input_one_line,
                         key: "phone", group: "bulk_payment", required: false,
                         width: :half, visibility: :logged_out_only)
    position = add_field(form, position, "Organization", :free_form_input_one_line,
                         key: "organization_name", group: "bulk_payment", required: false,
                         visibility: :logged_out_only)

    position = add_header(form, position, "Payment Information", group: "bulk_payment")
    position = add_field(form, position, "Payment method", :single_select_radio,
                         key: "payment_method", group: "bulk_payment", required: true,
                         options: PAYMENT_METHOD_OPTIONS)

    position = add_header(form, position, "Attendees", group: "bulk_payment")
    position = add_field(form, position, "Number of attendees", :free_form_input_one_line,
                         key: "number_of_attendees", group: "bulk_payment", required: true,
                         datatype: :number_integer, width: :half)
    position = add_field(form, position, "Attendees", :no_user_input,
                         key: "bulk_payment_attendees", group: "bulk_payment", required: false)
    position
  end
end
