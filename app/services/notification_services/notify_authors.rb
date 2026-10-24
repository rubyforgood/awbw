module NotificationServices
  class NotifyAuthors
    def self.call(record:, kind:)
      new(record:, kind:).call
    end

    def initialize(record:, kind:)
      @record = record
      @kind = kind
    end

    def call
      recipients.map do |person, email|
        CreateNotification.call(
          noticeable: @record,
          person: person,
          kind: @kind,
          recipient_role: :person,
          recipient_email: email,
          notification_type: 0)
      end
    end

    private

    # Anonymous credits still hear about their own record.
    def recipients
      @record.credited_author_entries.map(&:first)
        .filter_map { |person| [ person, person.preferred_email ] if person.preferred_email }
        .uniq { |_person, email| email.downcase }
    end
  end
end
