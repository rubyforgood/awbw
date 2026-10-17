module ProfileChangeRequests
  # Applies an auto-appliable change request (primary/secondary email, organization name).
  # Affiliation requests are free-form and resolved by a manual edit instead, so
  # they return applied: false with a message directing the admin to edit by hand.
  class Apply
    Result = Struct.new(:applied, :message, keyword_init: true)

    def self.call(request:, reviewer:)
      new(request:, reviewer:).call
    end

    def initialize(request:, reviewer:)
      @request = request
      @reviewer = reviewer
    end

    def call
      case @request.field
      when "primary_email" then apply_primary_email
      when "secondary_email" then apply_secondary_email
      when "organization_name" then apply_organization_name
      when "affiliation" then apply_affiliation
      else Result.new(applied: false, message: "This request needs a manual update.")
      end
    end

    private

    def apply_affiliation
      case @request.requested_value
      when ProfileChangeRequest::AFFILIATION_CHANGE_TITLE then apply_affiliation_title
      when ProfileChangeRequest::AFFILIATION_CHANGE_DATES then apply_affiliation_dates
      when ProfileChangeRequest::AFFILIATION_CHANGE_ORGANIZATION then apply_affiliation_organization
      when ProfileChangeRequest::AFFILIATION_CHANGE_REMOVE then apply_affiliation_remove
      when ProfileChangeRequest::AFFILIATION_CHANGE_ADD then apply_affiliation_add
      when *ProfileChangeRequest::AFFILIATION_WORK_ADDRESS_CATEGORIES then apply_affiliation_work_address
      else Result.new(applied: false, message: "This request needs a manual update.")
      end
    end

    def apply_affiliation_title
      affiliation = @request.affiliation
      return Result.new(applied: false, message: "The affiliation no longer exists.") unless affiliation

      affiliation.update(title: @request.proposed_title)
      Result.new(applied: true, message: "Title updated to #{@request.proposed_title}.")
    end

    def apply_affiliation_dates
      affiliation = @request.affiliation
      return Result.new(applied: false, message: "The affiliation no longer exists.") unless affiliation

      changes = {}
      changes[:start_date] = @request.proposed_start_date if @request.proposed_start_date
      changes[:end_date] = @request.proposed_end_date if @request.proposed_end_date
      affiliation.update(changes)
      Result.new(applied: true, message: "Affiliation dates updated.")
    end

    def apply_affiliation_organization
      affiliation = @request.affiliation
      organization = affiliation&.organization
      return Result.new(applied: false, message: "The affiliation no longer exists.") unless organization

      if organization.update(name: @request.proposed_organization_name)
        Result.new(applied: true, message: "Organization renamed to #{@request.proposed_organization_name}.")
      else
        Result.new(applied: false, message: organization.errors.full_messages.to_sentence)
      end
    end

    def apply_affiliation_remove
      affiliation = @request.affiliation
      return Result.new(applied: false, message: "The affiliation no longer exists.") unless affiliation

      affiliation.update(inactive: true, inactive_supplied: true, end_date: affiliation.end_date || Date.current)
      Result.new(applied: true, message: "Affiliation ended and marked inactive.")
    end

    def apply_affiliation_work_address
      affiliation = @request.affiliation
      return Result.new(applied: false, message: "The affiliation no longer exists.") unless affiliation

      return Result.new(applied: false, message: "This request needs a manual update.") unless @request.proposed_work_address_given?

      address = @request.proposed_organization_address || find_or_create_typed_address(affiliation.organization)
      return Result.new(applied: false, message: address.errors.full_messages.to_sentence) unless address.persisted?

      address.update(inactive: false) if address.inactive?
      roles = work_address_roles(affiliation)
      Affiliation.transaction { roles.each { |role| role.update!(organization_address: address) } }
      Result.new(applied: true, message: "Work address set to #{address.name} for #{roles.size} #{"role".pluralize(roles.size)} at #{affiliation.organization.name}.")
    rescue ActiveRecord::RecordInvalid => e
      Result.new(applied: false, message: e.record.errors.full_messages.to_sentence)
    end

    # A person works at one address per organization, so it applies to every active role there.
    def work_address_roles(affiliation)
      others = @request.person.affiliations.where(organization_id: affiliation.organization_id).where.not(id: affiliation.id).select(&:active?)
      [ affiliation, *others ]
    end

    # Reuses the org's address when the street and city already match, so approving doesn't add a duplicate.
    def find_or_create_typed_address(organization)
      street = AddressNormalizer.street(@request.proposed_street_address)
      city = AddressNormalizer.city(@request.proposed_city)
      existing = organization.addresses.find do |address|
        AddressNormalizer.street(address.street_address) == street && AddressNormalizer.city(address.city) == city
      end
      return existing if existing

      organization.addresses.create(
        street_address: @request.proposed_street_address,
        city: @request.proposed_city,
        state: @request.proposed_state,
        zip_code: @request.proposed_zip_code.to_s,
        locality: "Unknown",
        address_type: "work",
        primary: organization.addresses.active.where(primary: true).none?
      )
    end

    def apply_affiliation_add
      return Result.new(applied: false, message: "This organization isn't in the portal yet.") if @request.new_organization?

      affiliation = @request.person.affiliations.create(
        organization_id: @request.organization_id,
        title: @request.proposed_title,
        start_date: @request.proposed_start_date,
        end_date: @request.proposed_end_date
      )
      if affiliation.persisted?
        Result.new(applied: true, message: "New affiliation added.")
      else
        Result.new(applied: false, message: affiliation.errors.full_messages.to_sentence)
      end
    end

    def apply_primary_email
      user = @request.person.user
      return Result.new(applied: false, message: "This person has no user account.") unless user

      requested = @request.requested_value
      changing_address = user.email != requested
      return Result.new(applied: false, message: "That email is already in use by another account.") if changing_address && email_taken?(user, requested)

      type_message = apply_email_type(:email_type)
      return Result.new(applied: true, message: type_message || "Email already matches; nothing to send.") unless changing_address

      user.unconfirmed_email = requested
      user.email_type = @request.proposed_email_type if @request.proposed_email_type.present?
      user.save(validate: false)
      UserServices::ProcessEmailChange.call(user: user, send_confirmation: true, current_user: @reviewer)
      Result.new(applied: true, message: [ "Confirmation email sent to #{requested}.", type_message ].compact.join(" "))
    end

    def apply_secondary_email
      person = @request.person
      changes = { email_2: @request.requested_value, email_2_type: @request.proposed_email_type.presence }.compact
      return Result.new(applied: true, message: "Secondary email already matches.") if changes.all? { |attribute, value| person.public_send(attribute) == value }

      if person.update(changes)
        Result.new(applied: true, message: "Secondary email changed to #{PersonDecorator.email_with_type(person.email_2, person.email_2_type)}.")
      else
        Result.new(applied: false, message: person.errors.full_messages.to_sentence)
      end
    end

    # The person's type is the one shown; the login's copy rides along with an address change.
    def apply_email_type(attribute)
      type = @request.proposed_email_type.presence
      return if type.nil? || @request.person.public_send(attribute) == type
      return unless @request.person.update(attribute => type)

      "Email type set to #{type}."
    end

    def apply_organization_name
      organization = @request.target_organization
      return Result.new(applied: false, message: "This person has no organization to rename.") unless organization

      requested = @request.requested_value
      return Result.new(applied: true, message: "Organization name already matches.") if organization.name == requested

      if organization.update(name: requested)
        Result.new(applied: true, message: "Organization renamed to #{requested}.")
      else
        Result.new(applied: false, message: organization.errors.full_messages.to_sentence)
      end
    end

    def email_taken?(user, email)
      User.where.not(id: user.id).where("email = :e OR unconfirmed_email = :e", e: email).exists?
    end
  end
end
