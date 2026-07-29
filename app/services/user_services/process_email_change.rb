module UserServices
  class ProcessEmailChange
    Result = Struct.new(:actions_taken, keyword_init: true) do
      def summary
        return "User was successfully updated." if actions_taken.empty?
        "User was successfully updated. #{actions_taken.to_sentence}."
      end
    end

    def self.call(user:, send_confirmation:, current_user:)
      new(user:, send_confirmation:, current_user:).call
    end

    def initialize(user:, send_confirmation:, current_user:)
      @user = user
      @send_confirmation = send_confirmation
      @current_user = current_user
      @actions_taken = []
    end

    def call
      send_confirmation_email if @send_confirmation

      Result.new(actions_taken: @actions_taken)
    end

    private

    def send_confirmation_email
      return unless @user.unconfirmed_email.present?

      # Sending instructions regenerates the confirmation token and saves the record,
      # bumping updated_at; credit the acting admin so attribution isn't left on
      # whoever last edited the account. Devise only saves when it regenerates the
      # token, so persist the attribution ourselves if it was left dirty.
      @user.updated_by = @current_user
      @user.send_confirmation_instructions
      @user.save(validate: false) if @user.changed?
      @actions_taken << "A confirmation email has been sent to #{@user.unconfirmed_email}"
    end
  end
end
