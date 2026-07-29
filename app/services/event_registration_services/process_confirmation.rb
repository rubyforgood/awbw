module EventRegistrationServices
  class ProcessConfirmation
    Result = Struct.new(:actions_taken, keyword_init: true) do
      def summary
        return "Registration created." if actions_taken.empty?
        "Registration created. #{actions_taken.to_sentence}."
      end
    end

    def self.call(event_registration:, person:, create_user:, send_invite:,
                  send_confirmation_email:, send_admin_fyi:, current_user:)
      new(
        event_registration:,
        person:,
        create_user:,
        send_invite:,
        send_confirmation_email:,
        send_admin_fyi:,
        current_user:
      ).call
    end

    def initialize(event_registration:, person:, create_user:, send_invite:,
                   send_confirmation_email:, send_admin_fyi:, current_user:)
      @event_registration = event_registration
      @person = person
      @create_user = create_user
      @send_invite = send_invite
      @send_confirmation_email = send_confirmation_email
      @send_admin_fyi = send_admin_fyi
      @current_user = current_user
      @actions_taken = []
    end

    def call
      create_user_account if @create_user
      send_welcome_instructions if @send_invite
      send_registration_confirmation if @send_confirmation_email
      send_admin_fyi_notification if @send_admin_fyi

      Result.new(actions_taken: @actions_taken)
    end

    private

    def create_user_account
      return if @person.user.present?

      email = @person.preferred_email
      return if email.blank?

      password = SecureRandom.hex(8)
      user = User.new(
        email: email,
        password: password,
        password_confirmation: password,
        person: @person,
        created_by: @current_user,
        updated_by: @current_user
      )
      user.skip_confirmation_notification!

      if user.save
        @person.reload
        @actions_taken << "User account created"
      end
    end

    def send_welcome_instructions
      user = @person.user
      return unless user

      user.updated_by = @current_user
      user.set_welcome_instructions_token!
      user.update!(welcome_instructions_sent_at: Time.current, welcome_instructions_sent_by: @current_user)
      user.send_confirmation_instructions

      @actions_taken << "System invite sent"
    end

    def send_registration_confirmation
      email = @person.preferred_email
      return if email.blank?

      NotificationServices::CreateNotification.call(
        noticeable: @event_registration,
        kind: "event_registration_confirmation",
        recipient_role: :person,
        recipient_email: email,
        notification_type: 0
      )

      @actions_taken << "Registration confirmation email sent"
    end

    def send_admin_fyi_notification
      NotificationServices::CreateNotification.call(
        noticeable: @event_registration,
        kind: "event_registration_confirmation_fyi",
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0
      )

      @actions_taken << "Admin notification email sent"
    end
  end
end
