module ProfileChangeRequests
  # Applies an auto-appliable change request (primary email, organization name).
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

    def apply_affiliation_add
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
      return Result.new(applied: true, message: "Email already matches; nothing to send.") if user.email == requested
      return Result.new(applied: false, message: "That email is already in use by another account.") if email_taken?(user, requested)

      user.unconfirmed_email = requested
      user.save(validate: false)
      UserServices::ProcessEmailChange.call(user: user, send_confirmation: true, current_user: @reviewer)
      Result.new(applied: true, message: "Confirmation email sent to #{requested}.")
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
