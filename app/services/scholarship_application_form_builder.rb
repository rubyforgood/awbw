class ScholarshipApplicationFormBuilder
  FORM_NAME = "Scholarship Application"

  def self.build!(event)
    new(event).build!
  end

  def initialize(event)
    @event = event
  end

  def build!
    form = @event.forms.create!(name: FORM_NAME)
    position = 0

    position = build_contact_fields(form, position)
    position = build_agency_fields(form, position)
    position = build_service_fields(form, position)
    position = build_participant_fields(form, position)
    build_goals_fields(form, position)

    form
  end

  private

  def build_contact_fields(form, position)
    position = add_header(form, position, "Your Information", group: "contact")

    position = add_field(form, position, "First Name", :free_form_input_one_line,
                         key: "first_name", group: "contact", required: true)
    position = add_field(form, position, "Last Name", :free_form_input_one_line,
                         key: "last_name", group: "contact", required: true)
    position = add_field(form, position, "Primary Email Address", :free_form_input_one_line,
                         key: "primary_email", group: "contact", required: true)
    position = add_field(form, position, "Primary Email Type", :multiple_choice_radio,
                         key: "primary_email_type", group: "contact", required: true,
                         options: %w[Work Personal])
    position = add_field(form, position, "Secondary Email Address", :free_form_input_one_line,
                         key: "secondary_email", group: "contact", required: false)
    position = add_field(form, position, "Secondary Email Type", :multiple_choice_radio,
                         key: "secondary_email_type", group: "contact", required: false,
                         options: %w[Work Personal])

    position = add_header(form, position, "Primary Mailing Address", group: "contact")
    position = add_field(form, position, "Street Address", :free_form_input_one_line,
                         key: "mailing_street", group: "contact", required: true)
    position = add_field(form, position, "City", :free_form_input_one_line,
                         key: "mailing_city", group: "contact", required: true)
    position = add_field(form, position, "State / Province", :free_form_input_one_line,
                         key: "mailing_state", group: "contact", required: true)
    position = add_field(form, position, "Zip / Postal Code", :free_form_input_one_line,
                         key: "mailing_zip", group: "contact", required: true)
    position = add_field(form, position, "Mailing Address Type", :multiple_choice_radio,
                         key: "mailing_address_type", group: "contact", required: true,
                         options: %w[Work Personal])

    position = add_field(form, position, "Phone Number", :free_form_input_one_line,
                         key: "phone", group: "contact", required: true)
    position = add_field(form, position, "Phone Type", :multiple_choice_radio,
                         key: "phone_type", group: "contact", required: true,
                         options: %w[Work Personal])

    position = add_field(form, position, "Race / Ethnicity", :multiple_choice_checkbox,
                         key: "racial_ethnic_identity", group: "contact", required: true,
                         hint: "Select all that apply.",
                         options: [
                           "Alaskan Native", "American Indian", "Asian",
                           "Black / African American", "Latinx", "Middle Eastern",
                           "Multi-racial", "Native Hawaiian / Pacific Islander", "White"
                         ])

    position = add_field(form, position, "How did you hear about this training?", :multiple_choice_radio,
                         key: "referral_source", group: "contact", required: false,
                         options: [
                           "Online Search", "Social Media", "Presentation",
                           "Prior Agency Work", "Word of Mouth", "Foundation / Funder",
                           "Email from AWBW", "Other"
                         ])

    position
  end

  def build_agency_fields(form, position)
    position = add_header(form, position, "Agency Information", group: "agency")

    position = add_field(form, position, "Agency Name", :free_form_input_one_line,
                         key: "agency_name", group: "agency", required: true,
                         hint: "If your agency has a website, please put your agency name as it appears on the website. If you're not associated with an agency, please provide a name for your art program.")
    position = add_field(form, position, "Your Position", :free_form_input_one_line,
                         key: "agency_position", group: "agency", required: true)
    position = add_field(form, position, "Agency Type", :multiple_choice_radio,
                         key: "agency_type", group: "agency", required: true,
                         options: [ "501c3 / Nonprofit", "For-profit", "Government Agency", "Other" ])

    position = add_header(form, position, "Agency Address", group: "agency")
    position = add_field(form, position, "Agency Street Address", :free_form_input_one_line,
                         key: "agency_street", group: "agency", required: false)
    position = add_field(form, position, "Agency City", :free_form_input_one_line,
                         key: "agency_city", group: "agency", required: false)
    position = add_field(form, position, "Agency State / Province", :free_form_input_one_line,
                         key: "agency_state", group: "agency", required: false)
    position = add_field(form, position, "Agency Zip / Postal Code", :free_form_input_one_line,
                         key: "agency_zip", group: "agency", required: false)
    position = add_field(form, position, "Agency Website", :free_form_input_one_line,
                         key: "agency_website", group: "agency", required: false)
    position = add_field(form, position, "I / my agency cannot afford the full training cost and need a scholarship to attend.", :multiple_choice_checkbox,
                         key: "scholarship_eligibility", group: "agency", required: true,
                         options: [ "Yes" ])

    position
  end

  def build_service_fields(form, position)
    position = add_header(form, position, "Service Areas & Settings", group: "service")

    position = add_field(form, position, "Primary Service Area", :multiple_choice_radio,
                         key: "primary_service_area", group: "service", required: true,
                         hint: "Select the sector that best describes your primary work.",
                         options: [
                           "Community oppression / violence services",
                           "Criminal / legal services",
                           "Disability services",
                           "Domestic violence",
                           "Foster care / adoption",
                           "Homeless services",
                           "Human trafficking",
                           "Immigration services",
                           "Incarceration",
                           "Indigenous / tribal services",
                           "LGBTQIA+",
                           "Mental health",
                           "Reproductive services",
                           "Restorative / transformative justice",
                           "Sexual assault",
                           "Student services",
                           "Substance use",
                           "Other"
                         ])

    position = add_field(form, position, "Workshop Settings", :multiple_choice_checkbox,
                         key: "workshop_settings", group: "service", required: true,
                         hint: "Select all settings where you facilitate or plan to facilitate workshops.",
                         options: [
                           "Clinical", "Educational", "Events / conferences",
                           "Faith-based", "Home visits", "Hospitals",
                           "Law enforcement / court / legal", "Outreach",
                           "Prisons / jails", "Private practice", "Residential",
                           "Virtually", "With staff", "Other"
                         ])

    position
  end

  def build_participant_fields(form, position)
    position = add_header(form, position, "Participant Information", group: "participant")

    position = add_field(form, position, "Life Experiences Served", :multiple_choice_checkbox,
                         key: "client_life_experiences", group: "participant", required: true,
                         hint: "Select all that describe the populations you work with.",
                         options: [
                           "Child abuse / neglect", "Climate / environmental trauma",
                           "Community violence", "Domestic violence", "Elder abuse",
                           "Foster care", "Grief / loss", "Homelessness",
                           "Human trafficking", "Illness", "Immigration",
                           "Incarceration", "Mental health needs", "Military / veteran",
                           "LGBTQIA+ oppression", "Pandemic stress",
                           "People who do harm", "War experiences", "Poverty",
                           "Racism / marginalization", "Religious trauma",
                           "Restorative justice", "Secondary / vicarious trauma",
                           "Sexual assault", "Student stress", "Substance use",
                           "Suicidality", "Victims of crime", "Other"
                         ])

    position = add_field(form, position, "Primary Age Group Served", :multiple_choice_radio,
                         key: "primary_age_group", group: "participant", required: true,
                         options: [
                           "Adults (18+)", "Teens (13-17)", "Children (0-12)",
                           "Children & Teens (0-17)", "Families", "Elders (65+)"
                         ])

    position = add_field(form, position, "Training Motivation", :multiple_choice_checkbox,
                         key: "training_motivation", group: "participant", required: true,
                         hint: "Select all that apply.",
                         options: [
                           "Art for accessible programming",
                           "Trauma-informed practices",
                           "Address burnout",
                           "Support wellness",
                           "Community connection",
                           "Team building",
                           "Advocacy / awareness",
                           "AWBW Facilitator certification",
                           "Continuing Education hours",
                           "Other"
                         ])

    position
  end

  def build_goals_fields(form, position)
    position = add_header(form, position, "Your Goals", group: "goals")

    position = add_field(form, position,
                         "How will what you gain from this training directly impact the people you serve?",
                         :free_form_input_paragraph,
                         key: "impact_description", group: "goals", required: true,
                         hint: "Please describe in 3-5+ sentences.")
    position = add_field(form, position,
                         "Please describe one way in which you plan to use art workshops and how you envision it will help.",
                         :free_form_input_paragraph,
                         key: "implementation_plan", group: "goals", required: true,
                         hint: "Please describe in 3-5+ sentences.")
    position = add_field(form, position, "Anything else you'd like to share with us?", :free_form_input_paragraph,
                         key: "additional_comments", group: "goals", required: false)

    position
  end

  # --- helpers ---

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
end
