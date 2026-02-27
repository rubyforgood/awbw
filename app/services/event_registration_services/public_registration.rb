module EventRegistrationServices
  class PublicRegistration
    Result = Struct.new(:success?, :event_registration, :errors, keyword_init: true)

    def self.call(event:, form:, form_params:)
      new(event:, form:, form_params:).call
    end

    def initialize(event:, form:, form_params:)
      @event = event
      @form = form
      @form_params = form_params
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        person = find_or_create_person

        create_mailing_address(person) if field_value("mailing_city").present?
        create_phone_contact(person) if field_value("phone").present?

        organization = find_organization if field_value("agency_name").present?
        create_affiliation(person, organization) if organization
        create_agency_address(organization) if organization && field_value("agency_city").present?

        assign_tags(person, organization)

        event_registration = create_event_registration(person)
        create_user_form(user, event_registration)

        send_notifications(event_registration)

        Result.new(success?: true, event_registration: event_registration, errors: [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, event_registration: nil, errors: [ e.message ])
    rescue ActiveRecord::RecordNotUnique => e
      if e.message.include?("registrant_id")
        Result.new(success?: false, event_registration: nil,
                   errors: [ "You are already registered for this event." ])
      else
        Result.new(success?: false, event_registration: nil, errors: [ e.message ])
      end
    end

    private

    def field_value(key)
      field = @form.form_fields.find_by(field_key: key)
      return nil unless field
      @form_params[field.id.to_s]
    end

    def resolve_names
      submitted_first = field_value("first_name")&.strip
      nickname = field_value("nickname")&.strip

      if nickname.present?
        { first_name: nickname, legal_first_name: submitted_first }
      else
        { first_name: submitted_first, legal_first_name: nil }
      end
    end

    def find_or_create_person
      names = resolve_names
      first_name = names[:first_name]
      last_name = field_value("last_name")&.strip
      email = field_value("primary_email")&.strip&.downcase
      email_type = field_value("primary_email_type")&.downcase

      person = Person.find_by(
        "LOWER(first_name) = ? AND LOWER(last_name) = ? AND LOWER(email) = ?",
        first_name&.downcase, last_name&.downcase, email&.downcase
      )
      return person if person

      Person.create!(
        first_name: first_name,
        legal_first_name: names[:legal_first_name],
        last_name: last_name,
        pronouns: field_value("pronouns")&.strip,
        email: email,
        email_type: email_type,
        email_2: field_value("secondary_email")&.strip,
        email_2_type: field_value("secondary_email_type")&.downcase || "personal",
      )
    end

    def create_mailing_address(person)
      new_city = field_value("mailing_city")&.strip
      new_state = field_value("mailing_state")&.strip

      existing = person.addresses.find_by(
        "LOWER(city) = ? AND LOWER(COALESCE(state, '')) = ?",
        new_city&.downcase, new_state&.downcase.to_s
      )
      return existing if existing

      person.addresses.where(primary: true).update_all(primary: false, inactive: true)

      person.addresses.create!(
        street_address: field_value("mailing_street"),
        city: new_city,
        state: new_state,
        zip_code: field_value("mailing_zip"),
        locality: "Unknown",
        address_type: "mailing",
        primary: true
      )
    end

    def create_phone_contact(person)
      phone_value = field_value("phone")&.strip
      phone_type = field_value("phone_type")&.downcase
      contact_type = phone_type == "work" ? "work" : "personal"

      existing = person.contact_methods.find_by(kind: :phone, value: phone_value)
      return existing if existing

      person.contact_methods.where(kind: :phone, primary: true).update_all(primary: false, inactive: true)

      person.contact_methods.create!(
        kind: :phone,
        value: phone_value,
        contact_type: contact_type,
        primary: true
      )
    end

    def find_organization
      name = field_value("agency_name")&.strip
      return nil if name.blank?

      Organization.find_by(name: name)
    end

    def create_affiliation(person, organization)
      Affiliation.find_or_create_by!(
        person: person,
        organization: organization
      ) do |aff|
        aff.title = field_value("agency_position")
        aff.start_date = Date.current
      end
    end

    def create_agency_address(organization)
      new_city = field_value("agency_city")&.strip
      new_state = field_value("agency_state")&.strip

      existing = organization.addresses.find_by(
        "LOWER(city) = ? AND LOWER(COALESCE(state, '')) = ?",
        new_city&.downcase, new_state&.downcase.to_s
      )
      return existing if existing

      organization.addresses.where(primary: true).update_all(primary: false, inactive: true)

      organization.addresses.create!(
        street_address: field_value("agency_street"),
        city: new_city,
        state: new_state,
        zip_code: field_value("agency_zip"),
        locality: "Unknown",
        address_type: "work",
        primary: true
      )
    end

    def assign_tags(person, organization)
      sector_ids = collect_ids_from_checkboxes("primary_service_area")
      category_ids = collect_ids_from_checkboxes("workshop_environments") +
                     collect_ids_from_checkboxes("client_life_experiences") +
                     collect_ids_from_checkboxes("primary_age_group")

      if sector_ids.any?
        sectors = Sector.where(id: sector_ids)
        person.sectors = (person.sectors + sectors).uniq
        organization.sectors = (organization.sectors + sectors).uniq if organization
      end

      if category_ids.any?
        categories = Category.where(id: category_ids)
        person.categories = (person.categories + categories).uniq
        organization.categories = (organization.categories + categories).uniq if organization
      end
    end

    def collect_ids_from_checkboxes(field_key)
      field = @form.form_fields.find_by(field_key: field_key)
      return [] unless field

      value = @form_params[field.id.to_s]
      Array(value).reject(&:blank?).map(&:to_i)
    end

    def create_event_registration(person)
      @event.event_registrations.create!(registrant: person)
    end

    def create_user_form(user, event_registration)
      user_form = UserForm.create!(user: user, form: @form)

      @form.form_fields.where(status: :active).find_each do |field|
        next if field.group_header?

        raw_value = @form_params[field.id.to_s]
        text = if raw_value.is_a?(Array)
          raw_value.reject(&:blank?).join(", ")
        else
          raw_value.to_s
        end

        UserFormFormField.create!(
          user_form: user_form,
          form_field: field,
          text: text
        )
      end

      user_form
    end

    def send_notifications(event_registration)
      registrant_email = event_registration.registrant.preferred_email

      NotificationServices::CreateNotification.call(
        noticeable: event_registration,
        kind: :event_registration_confirmation,
        recipient_role: :person,
        recipient_email: registrant_email,
        notification_type: 0
      )

      NotificationServices::CreateNotification.call(
        noticeable: event_registration,
        kind: :event_registration_confirmation_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0
      )
    end
  end
end
