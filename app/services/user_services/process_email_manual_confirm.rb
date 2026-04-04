module UserServices
  class ProcessEmailManualConfirm
    Result = Struct.new(:actions_taken, keyword_init: true) do
      def summary
        actions_taken.to_sentence.presence || "No action taken."
      end
    end

    def self.call(user:, action:, send_reset_password: false, current_user:)
      new(user:, action:, send_reset_password:, current_user:).call
    end

    def initialize(user:, action:, send_reset_password:, current_user:)
      @user = user
      @action = action
      @send_reset_password = send_reset_password
      @current_user = current_user
      @actions_taken = []
    end

    def call
      case @action
      when "resend"
        resend_confirmation
      when "confirm"
        manually_confirm
        send_reset_password_instructions if @send_reset_password
      end

      Result.new(actions_taken: @actions_taken)
    end

    private

    def resend_confirmation
      target_email = @user.unconfirmed_email.presence || @user.email
      @user.send_confirmation_instructions
      @actions_taken << "Confirmation email has been resent to #{target_email}"
    end

    def manually_confirm
      pending_email = @user.unconfirmed_email
      @user.confirm
      if pending_email.present?
        @actions_taken << "Email change to #{pending_email} has been manually confirmed"
      else
        @actions_taken << "Email has been manually confirmed"
      end
    end

    def send_reset_password_instructions
      @user.send_reset_password_instructions
      @actions_taken << "Password reset instructions sent to #{@user.email}"
    end
  end
end
