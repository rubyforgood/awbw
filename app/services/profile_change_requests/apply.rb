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

      user.unconfirmed_email = @request.requested_value
      user.save(validate: false)
      UserServices::ProcessEmailChange.call(user: user, send_confirmation: true, current_user: @reviewer)
      Result.new(applied: true, message: "Confirmation email sent to #{@request.requested_value}.")
    end

    def apply_organization_name
      organization = @request.person.primary_organization
      return Result.new(applied: false, message: "This person has no primary organization.") unless organization

      if organization.update(name: @request.requested_value)
        Result.new(applied: true, message: "Organization renamed to #{@request.requested_value}.")
      else
        Result.new(applied: false, message: organization.errors.full_messages.to_sentence)
      end
    end
  end
end
