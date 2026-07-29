module UserServices
  class ProcessEmailManualConfirm
    Result = Struct.new(:actions_taken, keyword_init: true) do
      def summary
        actions_taken.to_sentence.presence || "No action taken."
      end
    end

    def self.call(user:, action:, current_user:)
      new(user:, action:, current_user:).call
    end

    def initialize(user:, action:, current_user:)
      @user = user
      @action = action
      @current_user = current_user
      @actions_taken = []
    end

    def call
      case @action
      when "resend"
        resend_confirmation
      when "confirm"
        manually_confirm
      end

      Result.new(actions_taken: @actions_taken)
    end

    private

    def resend_confirmation
      target_email = @user.unconfirmed_email.presence || @user.email
      # Credit the acting admin. Devise saves only when it regenerates the token,
      # so persist the attribution ourselves if it's left dirty.
      @user.updated_by = @current_user
      @user.send_confirmation_instructions
      @user.save(validate: false) if @user.changed?
      @actions_taken << "Confirmation email has been resent to #{target_email}"
    end

    def manually_confirm
      pending_email = @user.unconfirmed_email
      @user.updated_by = @current_user
      @user.confirm
      if pending_email.present?
        @actions_taken << "Email change to #{pending_email} has been manually confirmed"
      else
        @actions_taken << "Email has been manually confirmed"
      end
    end
  end
end
