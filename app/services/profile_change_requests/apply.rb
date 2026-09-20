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
      else Result.new(applied: false, message: "This request needs a manual update.")
      end
    end

    private

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
