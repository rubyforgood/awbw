class ExtendedEventRegistrationFormBuilder < BaseRegistrationFormBuilder
  FORM_NAME = "Extended Event Registration"

  def self.build_standalone!(include_contact_fields: true)
    form = Form.create!(name: FORM_NAME)
    new(nil, include_contact_fields:).build_fields!(form)
    form
  end

  def self.build!(event, include_contact_fields: true)
    form = Form.create!(name: FORM_NAME)
    new(event, include_contact_fields:).build_fields!(form)
    EventForm.create!(event: event, form: form, role: "registration") if event
    form
  end

  def self.copy!(from_form:, to_event:)
    new_form = Form.create!(
      name: from_form.name,
      form_builder_id: from_form.form_builder_id
    )

    from_form.form_fields.unscoped.where(form_id: from_form.id).order(:position).each do |source_field|
      new_field = new_form.form_fields.create!(
        question: source_field.question,
        answer_type: source_field.answer_type,
        answer_datatype: source_field.answer_datatype,
        status: source_field.status,
        position: source_field.position,
        is_required: source_field.is_required,
        instructional_hint: source_field.instructional_hint,
        field_key: source_field.field_key,
        field_group: source_field.field_group
      )

      source_field.form_field_answer_options.each do |ffao|
        new_field.form_field_answer_options.create!(answer_option: ffao.answer_option)
      end
    end

    EventForm.create!(event: to_event, form: new_form, role: "registration")
    new_form
  end

  def initialize(event = nil, include_contact_fields: true)
    @event = event
    @include_contact_fields = include_contact_fields
  end

  def build_fields!(form)
    position = 0

    if @include_contact_fields
      position = build_contact_fields(form, position)
    end

    position = build_background_fields(form, position)
    position = build_professional_fields(form, position)
    position = build_qualitative_fields(form, position)
    position = build_scholarship_fields(form, position)
    position = build_payment_fields(form, position)
    build_consent_fields(form, position)

    form
  end

  private

  def build_contact_fields(form, position)
    position = add_header(form, position, "Contact Information", group: "contact")

    position = build_basic_contact_fields(form, position)

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

  def build_background_fields(form, position)
    position = add_header(form, position, "Background Information", group: "background")

    position = add_field(form, position, "Racial / Ethnic Identity", :free_form_input_one_line,
                         key: "racial_ethnic_identity", group: "background", required: false,
                         hint: "This information helps us understand the diversity of our community.")

    position
  end

  def build_professional_fields(form, position)
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

  def build_qualitative_fields(form, position)
    position = add_header(form, position, "About You", group: "qualitative")

    position = add_field(form, position, "How did you hear about this training?", :free_form_input_paragraph,
                         key: "referral_source", group: "qualitative", required: false)
    position = add_field(form, position, "What motivates you to attend this training?", :free_form_input_paragraph,
                         key: "training_motivation", group: "qualitative", required: false)
    position = add_field(form, position, "Are you interested in learning more about upcoming trainings or resources?", :multiple_choice_radio,
                         key: "interested_in_more", group: "qualitative", required: true,
                         options: %w[Yes No])

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
end
