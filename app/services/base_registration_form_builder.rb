class BaseRegistrationFormBuilder
  protected

  def build_basic_contact_fields(form, position)
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

  def build_consent_fields(form, position)
    position = add_header(form, position, "Consent", group: "consent")
    position = add_field(form, position,
                         "I agree to receive email communications from A Window Between Worlds.",
                         :multiple_choice_radio,
                         key: "communication_consent", group: "consent", required: true,
                         hint: "By submitting this form, I consent to receive updates from A Window Between Worlds, " \
                               "including information about this event as well as upcoming events, training opportunities, resources, " \
                               "impact stories, and ways to support our mission. I understand I can unsubscribe at any time.",
                         options: %w[Yes No])

    position
  end

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
