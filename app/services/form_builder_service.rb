class FormBuilderService
  SECTIONS = {
    person_identifier: { label: "Person identifier", method: :build_person_identifier_fields },
    person_contact_info: { label: "Person contact info", method: :build_person_contact_info_fields },
    person_background: { label: "Person background", method: :build_person_background_fields },
    professional_info: { label: "Professional info", method: :build_professional_info_fields },
    event_feedback: { label: "Event feedback", method: :build_event_feedback_fields },
    scholarship: { label: "Scholarship", method: :build_scholarship_fields },
    payment: { label: "Payment", method: :build_payment_fields },
    consent: { label: "Consent", method: :build_consent_fields },
    post_event_feedback: { label: "Post-event feedback", method: :build_post_event_feedback_fields }
  }.freeze

  def initialize(name:, sections:, scholarship_application: false)
    @name = name
    @sections = sections.map(&:to_sym)
    @scholarship_application = scholarship_application
  end

  def call
    form = Form.create!(
      name: @name,
      sections: @sections.map(&:to_s),
      scholarship_application: @scholarship_application
    )

    position = 0
    @sections.each do |key|
      section = SECTIONS.fetch(key)
      position = send(section[:method], form, position)
    end

    form
  end

  SECTION_FIELD_KEYS = {
    person_identifier: %w[first_name last_name primary_email confirm_email],
    person_contact_info: %w[
      primary_email_type nickname pronouns secondary_email secondary_email_type
      mailing_street mailing_address_type mailing_city mailing_state mailing_zip
      phone phone_type agency_name agency_position agency_street agency_city
      agency_state agency_zip agency_type agency_website
    ],
    person_background: %w[racial_ethnic_identity],
    professional_info: %w[primary_service_area workshop_environments client_life_experiences primary_age_group],
    event_feedback: %w[referral_source training_motivation interested_in_more],
    scholarship: %w[scholarship_eligibility impact_description implementation_plan additional_comments],
    payment: %w[number_of_attendees payment_method],
    consent: %w[communication_consent],
    post_event_feedback: %w[event_rating most_valuable improvement_suggestions]
  }.freeze

  # Update sections on an existing form: add new sections, remove unchecked ones
  def self.update_sections!(form, new_sections)
    new_sections = new_sections.map(&:to_sym)
    old_sections = (form.sections || []).map(&:to_sym)

    added = new_sections - old_sections
    removed = old_sections - new_sections

    # Remove fields belonging to removed sections
    remaining_groups = new_sections.map { |k| SECTION_FIELD_GROUPS.fetch(k) }.uniq
    removed.each do |key|
      field_keys = SECTION_FIELD_KEYS.fetch(key)
      form.form_fields.where(field_key: field_keys).destroy_all
      # Only remove headers if no remaining section shares the same field_group
      group = SECTION_FIELD_GROUPS.fetch(key)
      unless remaining_groups.include?(group)
        form.form_fields.where(field_key: nil, field_group: group, answer_type: :group_header).destroy_all
      end
    end

    # Add fields for new sections at the end
    if added.any?
      max_position = form.form_fields.maximum(:position) || 0
      builder = new(name: form.name, sections: added)
      added.each do |key|
        section = SECTIONS.fetch(key)
        max_position = builder.send(section[:method], form, max_position)
      end
    end

    form.update!(sections: new_sections.map(&:to_s))
    form
  end

  SECTION_FIELD_GROUPS = {
    person_identifier: "contact",
    person_contact_info: "contact",
    person_background: "background",
    professional_info: "professional",
    event_feedback: "event_feedback",
    scholarship: "scholarship",
    payment: "payment",
    consent: "consent",
    post_event_feedback: "post_event_feedback"
  }.freeze

  private

  def add_header(form, position, title, group:)
    position += 1
    form.form_fields.create!(
      question: title,
      answer_type: :group_header,
      status: :active,
      position: position,
      is_required: false,
      field_key: nil,
      field_group: group
    )
    position
  end

  def add_field(form, position, question, answer_type, key:, group:, required: true, hint: nil, options: nil, datatype: nil)
    position += 1
    field = form.form_fields.create!(
      question: question,
      answer_type: answer_type,
      answer_datatype: datatype,
      status: :active,
      position: position,
      is_required: required,
      instructional_hint: hint,
      field_key: key,
      field_group: group
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
                         key: "first_name", group: "contact", required: true)
    position = add_field(form, position, "Last Name", :free_form_input_one_line,
                         key: "last_name", group: "contact", required: true)
    position = add_field(form, position, "Email", :free_form_input_one_line,
                         key: "primary_email", group: "contact", required: true)
    position = add_field(form, position, "Confirm Email", :free_form_input_one_line,
                         key: "confirm_email", group: "contact", required: true)
    position
  end

  def build_person_contact_info_fields(form, position)
    position = add_header(form, position, "Contact Information", group: "contact")

    position = add_field(form, position, "Primary Email Type", :multiple_choice_radio,
                         key: "primary_email_type", group: "contact", required: true,
                         options: %w[Personal Work])
    position = add_field(form, position, "Preferred Nickname", :free_form_input_one_line,
                         key: "nickname", group: "contact", required: false)
    position = add_field(form, position, "Pronouns", :free_form_input_one_line,
                         key: "pronouns", group: "contact", required: false)
    position = add_field(form, position, "Secondary Email", :free_form_input_one_line,
                         key: "secondary_email", group: "contact", required: false)
    position = add_field(form, position, "Secondary Email Type", :multiple_choice_radio,
                         key: "secondary_email_type", group: "contact", required: false,
                         options: %w[Personal Work])

    position = add_header(form, position, "Mailing Address", group: "contact")
    position = add_field(form, position, "Street Address", :free_form_input_one_line,
                         key: "mailing_street", group: "contact", required: true)
    position = add_field(form, position, "Address Type", :multiple_choice_radio,
                         key: "mailing_address_type", group: "contact", required: true,
                         options: %w[Home Work])
    position = add_field(form, position, "City", :free_form_input_one_line,
                         key: "mailing_city", group: "contact", required: true)
    position = add_field(form, position, "State / Province", :free_form_input_one_line,
                         key: "mailing_state", group: "contact", required: true)
    position = add_field(form, position, "Zip / Postal Code", :free_form_input_one_line,
                         key: "mailing_zip", group: "contact", required: true)

    position = add_field(form, position, "Phone", :free_form_input_one_line,
                         key: "phone", group: "contact", required: true)
    position = add_field(form, position, "Phone Type", :multiple_choice_radio,
                         key: "phone_type", group: "contact", required: true,
                         options: %w[Mobile Home Work])

    position = add_header(form, position, "Agency / Organization Information", group: "contact")
    position = add_field(form, position, "Agency / Organization Name", :free_form_input_one_line,
                         key: "agency_name", group: "contact", required: false)
    position = add_field(form, position, "Position / Title", :free_form_input_one_line,
                         key: "agency_position", group: "contact", required: false)
    position = add_field(form, position, "Agency Street Address", :free_form_input_one_line,
                         key: "agency_street", group: "contact", required: false)
    position = add_field(form, position, "Agency City", :free_form_input_one_line,
                         key: "agency_city", group: "contact", required: false)
    position = add_field(form, position, "Agency State / Province", :free_form_input_one_line,
                         key: "agency_state", group: "contact", required: false)
    position = add_field(form, position, "Agency Zip / Postal Code", :free_form_input_one_line,
                         key: "agency_zip", group: "contact", required: false)
    position = add_field(form, position, "Agency Type", :multiple_choice_radio,
                         key: "agency_type", group: "contact", required: false,
                         options: [
                           "Domestic Violence", "Homeless Shelter", "Hospital",
                           "Mental Health", "School", "After-School Program",
                           "Community Center", "Other"
                         ])
    position = add_field(form, position, "Agency Website", :free_form_input_one_line,
                         key: "agency_website", group: "contact", required: false)
    position
  end

  def build_person_background_fields(form, position)
    position = add_header(form, position, "Background Information", group: "background")

    position = add_field(form, position, "Racial / Ethnic Identity", :free_form_input_one_line,
                         key: "racial_ethnic_identity", group: "background", required: false,
                         hint: "This information helps us understand the diversity of our community.")
    position
  end

  def build_professional_info_fields(form, position)
    position = add_header(form, position, "Professional Information", group: "professional")

    position = add_field(form, position, "Primary Service Area(s)", :multiple_choice_checkbox,
                         key: "primary_service_area", group: "professional", required: false,
                         hint: "Select all that apply. These represent the sectors you primarily serve.")
    position = add_field(form, position, "Workshop Settings", :multiple_choice_checkbox,
                         key: "workshop_environments", group: "professional", required: false,
                         hint: "Select all settings where you facilitate or plan to facilitate workshops.",
                         options: [
                           "Clinical", "Educational", "Events / conferences",
                           "Faith-based", "Home visits", "Hospitals",
                           "Law enforcement / court / legal", "Outreach",
                           "Prisons / jails", "Private practice", "Residential",
                           "Virtually", "With staff", "Other"
                         ])
    position = add_field(form, position, "Client Life Experiences", :multiple_choice_checkbox,
                         key: "client_life_experiences", group: "professional", required: false,
                         hint: "Select all that describe the populations you work with.")
    position = add_field(form, position, "Primary Age Group(s) Served", :multiple_choice_checkbox,
                         key: "primary_age_group", group: "professional", required: false,
                         hint: "Select all age groups you primarily serve.")
    position
  end

  def build_event_feedback_fields(form, position)
    position = add_header(form, position, "About You", group: "event_feedback")

    position = add_field(form, position, "How did you hear about this training?", :free_form_input_paragraph,
                         key: "referral_source", group: "event_feedback", required: false)
    position = add_field(form, position, "What motivates you to attend this training?", :free_form_input_paragraph,
                         key: "training_motivation", group: "event_feedback", required: false)
    position = add_field(form, position, "Are you interested in learning more about upcoming trainings or resources?",
                         :multiple_choice_radio,
                         key: "interested_in_more", group: "event_feedback", required: true,
                         options: %w[Yes No])
    position
  end

  def build_scholarship_fields(form, position)
    position = add_header(form, position, "Scholarship Application", group: "scholarship")

    position = add_field(form, position,
                         "I / my agency cannot afford the full training cost and need a scholarship to attend.",
                         :multiple_choice_checkbox,
                         key: "scholarship_eligibility", group: "scholarship", required: true,
                         options: [ "Yes" ])
    position = add_field(form, position,
                         "How will what you gain from this training directly impact the people you serve?",
                         :free_form_input_paragraph,
                         key: "impact_description", group: "scholarship", required: true,
                         hint: "Please describe in 3-5+ sentences.")
    position = add_field(form, position,
                         "Please describe one way in which you plan to use art workshops and how you envision it will help.",
                         :free_form_input_paragraph,
                         key: "implementation_plan", group: "scholarship", required: true,
                         hint: "Please describe in 3-5+ sentences.")
    position = add_field(form, position, "Anything else you'd like to share with us?", :free_form_input_paragraph,
                         key: "additional_comments", group: "scholarship", required: false)
    position
  end

  def build_payment_fields(form, position)
    position = add_header(form, position, "Payment Information", group: "payment")

    position = add_field(form, position, "Number of Attendees", :free_form_input_one_line,
                         key: "number_of_attendees", group: "payment", required: true,
                         hint: "How many people are you registering (including yourself)?",
                         datatype: :number_integer)
    position = add_field(form, position, "Payment Method", :multiple_choice_radio,
                         key: "payment_method", group: "payment", required: true,
                         options: [ "Credit Card", "Check", "Purchase Order", "Other" ])
    position
  end

  def build_consent_fields(form, position)
    position = add_header(form, position, "Consent", group: "consent")
    position = add_field(form, position,
                         "I agree to receive email communications from A Window Between Worlds.",
                         :multiple_choice_checkbox,
                         key: "communication_consent", group: "consent", required: true,
                         hint: "By submitting this form, I consent to receive updates from A Window Between Worlds, " \
                               "including information about this event as well as upcoming events, training opportunities, resources, " \
                               "impact stories, and ways to support our mission. I understand I can unsubscribe at any time.",
                         options: [ "Yes" ])
    position
  end

  def build_post_event_feedback_fields(form, position)
    position = add_header(form, position, "Post-Event Feedback", group: "post_event_feedback")

    position = add_field(form, position, "How would you rate this event?", :multiple_choice_radio,
                         key: "event_rating", group: "post_event_feedback", required: true,
                         options: [ "Excellent", "Good", "Fair", "Poor" ])
    position = add_field(form, position, "What did you find most valuable?", :free_form_input_paragraph,
                         key: "most_valuable", group: "post_event_feedback", required: false)
    position = add_field(form, position, "Any suggestions for improvement?", :free_form_input_paragraph,
                         key: "improvement_suggestions", group: "post_event_feedback", required: false)
    position
  end
end
