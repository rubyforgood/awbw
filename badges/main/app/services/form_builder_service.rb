class FormBuilderService
  SECTIONS = {
    person_identifier: { label: "Person identifier", method: :build_person_identifier_fields },
    person_contact_info: { label: "Person contact info", method: :build_person_contact_info_fields },
    person_background: { label: "Person background", method: :build_person_background_fields },
    professional_info: { label: "Professional info", method: :build_professional_info_fields },
    marketing: { label: "Marketing", method: :build_marketing_fields },
    scholarship: { label: "Scholarship", method: :build_scholarship_fields },
    payment: { label: "Payment", method: :build_payment_fields },
    consent: { label: "Consent", method: :build_consent_fields },
    post_event_feedback: { label: "Post-event feedback", method: :build_post_event_feedback_fields },
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
      mailing_street mailing_address_type mailing_city mailing_state mailing_zip
      phone phone_type agency_name agency_position agency_street agency_city
      agency_state agency_zip agency_type agency_website
    ],
    person_background: %w[racial_ethnic_identity],
    professional_info: %w[primary_service_area workshop_environments client_life_experiences primary_age_group],
    marketing: %w[referral_source training_motivation interested_in_more],
    scholarship: %w[scholarship_eligibility impact_description implementation_plan additional_comments],
    payment: %w[payment_method],
    consent: %w[communication_consent],
    post_event_feedback: %w[event_rating most_valuable improvement_suggestions],
    bulk_payment: %w[payer_first_name payer_last_name payer_email organization_name number_of_attendees payment_method bulk_payment_attendees]
  }.freeze

  # Header questions created by each section's builder method
  SECTION_HEADERS = {
    person_identifier: [],
    person_contact_info: [ "Contact Information", "Mailing Address", "Agency / Organization Information" ],
    person_background: [ "Background Information" ],
    professional_info: [ "Professional Information" ],
    marketing: [ "Marketing" ],
    scholarship: [ "Scholarship Application" ],
    payment: [ "Payment Information" ],
    consent: [ "Consent" ],
    post_event_feedback: [ "Post-Event Feedback" ],
    bulk_payment: [ "Payer Information", "Payment Information", "Attendees" ]
  }.freeze

  # Maps each section to the `section` column value(s) its builder assigns to
  # fields, so fields can be grouped back to their section when reordering.
  # Several builders use a `group:` string that differs from the section key.
  SECTION_GROUPS = {
    person_identifier: %w[person_identifier],
    person_contact_info: %w[person_contact_info],
    person_background: %w[background],
    professional_info: %w[professional],
    marketing: %w[marketing],
    scholarship: %w[scholarship],
    payment: %w[payment],
    consent: %w[consent],
    post_event_feedback: %w[post_event_feedback],
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
      else key != :scholarship && key != :bulk_payment
      end
    end
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
    customs = []
    current = nil

    # Rank by iteration order rather than the stored position, which is nullable
    # and can collide, so the sort keys below are always comparable integers.
    form.form_fields.reorder(position: :asc).each_with_index do |field, order|
      key = group_to_key[field.section]
      if key
        current = nil
        positions[key] ||= order
        header_names[key] ||= field.name if field.group_header?
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
    old_sections = (form.sections || []).map(&:to_sym)

    remove_custom_sections!(form, remove_custom_section_ids)

    added = new_sections - old_sections
    removed = old_sections - new_sections

    # Remove fields and headers belonging to removed sections
    removed.each do |key|
      identifiers = SECTION_FIELD_IDENTIFIERS.fetch(key)
      form.form_fields.where(field_identifier: identifiers).destroy_all

      headers = SECTION_HEADERS.fetch(key)
      if headers.any?
        form.form_fields.where(name: headers, answer_type: :group_header).destroy_all
      end
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

  def add_field(form, position, field_name, answer_type, key:, group:, required: true, hint: nil, options: nil, datatype: nil, visibility: nil, width: :full)
    position += 1
    field = form.form_fields.create!(
      name: field_name,
      answer_type: answer_type,
      input_type: datatype,
      status: :active,
      position: position,
      required: required,
      hint_text: hint,
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

    position = add_field(form, position, "Primary Email Type", :multiple_choice_radio,
                         key: "primary_email_type", group: "person_contact_info", required: true,
                         options: %w[Personal Work])
    position = add_field(form, position, "Preferred Nickname", :free_form_input_one_line,
                         key: "nickname", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Pronouns", :free_form_input_one_line,
                         key: "pronouns", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Secondary Email", :free_form_input_one_line,
                         key: "secondary_email", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Secondary Email Type", :multiple_choice_radio,
                         key: "secondary_email_type", group: "person_contact_info", required: false,
                         width: :half, options: %w[Personal Work])

    position = add_header(form, position, "Mailing Address", group: "person_contact_info")
    position = add_field(form, position, "Street Address", :free_form_input_one_line,
                         key: "mailing_street", group: "person_contact_info", required: true, width: :half)
    position = add_field(form, position, "Address Type", :multiple_choice_radio,
                         key: "mailing_address_type", group: "person_contact_info", required: true,
                         width: :half, options: %w[Work Personal])
    position = add_field(form, position, "City", :free_form_input_one_line,
                         key: "mailing_city", group: "person_contact_info", required: true, width: :third)
    position = add_field(form, position, "State / Province", :free_form_input_one_line,
                         key: "mailing_state", group: "person_contact_info", required: true, width: :third)
    position = add_field(form, position, "Zip / Postal Code", :free_form_input_one_line,
                         key: "mailing_zip", group: "person_contact_info", required: true, width: :third)

    position = add_field(form, position, "Phone", :free_form_input_one_line,
                         key: "phone", group: "person_contact_info", required: true, width: :half)
    position = add_field(form, position, "Phone Type", :multiple_choice_radio,
                        key: "phone_type", group: "person_contact_info", required: true,
                        width: :half, options: %w[Work Personal])

    position = add_header(form, position, "Agency / Organization Information", group: "person_contact_info")
    position = add_field(form, position, "Agency / Organization Name", :free_form_input_one_line,
                         key: "agency_name", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Position / Title", :free_form_input_one_line,
                         key: "agency_position", group: "person_contact_info", required: false, width: :half)
    position = add_field(form, position, "Agency Street Address", :free_form_input_one_line,
                         key: "agency_street", group: "person_contact_info", required: false)
    position = add_field(form, position, "Agency City", :free_form_input_one_line,
                         key: "agency_city", group: "person_contact_info", required: false, width: :third)
    position = add_field(form, position, "Agency State / Province", :free_form_input_one_line,
                         key: "agency_state", group: "person_contact_info", required: false, width: :third)
    position = add_field(form, position, "Agency Zip / Postal Code", :free_form_input_one_line,
                         key: "agency_zip", group: "person_contact_info", required: false, width: :third)
    position = add_field(form, position, "Agency Type", :multiple_choice_radio,
                         key: "agency_type", group: "person_contact_info", required: false,
                         options: [
                           "501c3/nonprofit", "For-profit", "Government agency",
                           "Other (please specify below)"
                         ])
    position = add_field(form, position, "Agency Website", :free_form_input_one_line,
                         key: "agency_website", group: "person_contact_info", required: false)
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

  def build_marketing_fields(form, position)
    position = add_header(form, position, "Marketing", group: "marketing")

    position = add_field(form, position, "How did you hear about this training?", :free_form_input_paragraph,
                         key: "referral_source", group: "marketing", required: false)
    position = add_field(form, position, "What motivates you to attend this training?", :free_form_input_paragraph,
                         key: "training_motivation", group: "marketing", required: false)
    position = add_field(form, position, "Are you interested in learning more about upcoming trainings or resources?",
                         :multiple_choice_radio,
                         key: "interested_in_more", group: "marketing", required: true,
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

    position = add_field(form, position, "Payment Method", :multiple_choice_radio,
                         key: "payment_method", group: "payment", required: true,
                         options: [ "Credit Card Now", "Credit Card Later", "Check", "Other" ])
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

  def build_bulk_payment_fields(form, position)
    position = add_header(form, position, "Payer Information", group: "bulk_payment", visibility: :logged_out_only)

    position = add_field(form, position, "Payer First Name", :free_form_input_one_line,
                         key: "payer_first_name", group: "bulk_payment", required: true,
                         width: :half, visibility: :logged_out_only)
    position = add_field(form, position, "Payer Last Name", :free_form_input_one_line,
                         key: "payer_last_name", group: "bulk_payment", required: true,
                         width: :half, visibility: :logged_out_only)
    position = add_field(form, position, "Payer Email", :free_form_input_one_line,
                         key: "payer_email", group: "bulk_payment", required: true,
                         visibility: :logged_out_only)
    position = add_field(form, position, "Organization Name", :free_form_input_one_line,
                         key: "organization_name", group: "bulk_payment", required: false,
                         visibility: :logged_out_only)

    position = add_header(form, position, "Payment Information", group: "bulk_payment")
    position = add_field(form, position, "Payment Method", :multiple_choice_radio,
                         key: "payment_method", group: "bulk_payment", required: true,
                         options: [ "Credit Card Now", "Credit Card Later", "Check", "Other" ])

    position = add_header(form, position, "Attendees", group: "bulk_payment")
    position = add_field(form, position, "Number of Attendees", :free_form_input_one_line,
                         key: "number_of_attendees", group: "bulk_payment", required: true,
                         datatype: :number_integer)
    position = add_field(form, position, "Attendees", :no_user_input,
                         key: "bulk_payment_attendees", group: "bulk_payment", required: false)
    position
  end
end
