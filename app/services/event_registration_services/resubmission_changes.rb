module EventRegistrationServices
  # Plain-language notes on what a resubmission changed on an existing registration.
  # They travel in the duplicate notifications' custom_message, one note per line.
  class ResubmissionChanges
    SCHOLARSHIP_REQUESTED = "Scholarship now requested".freeze

    NEWLY_REQUESTED_NOTES = {
      scholarship_requested: SCHOLARSHIP_REQUESTED,
      ce_requested: "Continuing education credit now requested",
      w9_requested: "W-9 now requested",
      invoice_requested: "Invoice now requested"
    }.freeze

    attr_reader :notes

    def self.snapshot(registration)
      {
        scholarship_requested: registration.scholarship_requested?,
        ce_requested: registration.continuing_education_registrations.exists?,
        w9_requested: registration.w9_requested?,
        invoice_requested: registration.invoice_requested?,
        expected_payment_method: registration.expected_payment_method.presence,
        someone_else_will_pay: registration.someone_else_will_pay?
      }
    end

    def self.between(before, after)
      notes = NEWLY_REQUESTED_NOTES.filter_map { |key, note| note if after[key] && !before[key] }
      if before[:expected_payment_method] != after[:expected_payment_method]
        notes << "Payment method changed from #{before[:expected_payment_method] || "none"} to #{after[:expected_payment_method] || "none"}"
      end
      if before[:someone_else_will_pay] != after[:someone_else_will_pay]
        notes << (after[:someone_else_will_pay] ? "Someone else will now pay" : "Someone else is no longer paying")
      end
      new(notes)
    end

    def self.from_message(message)
      new(message.to_s.split("\n").map(&:strip).compact_blank)
    end

    def initialize(notes)
      @notes = notes
    end

    def to_message
      @notes.join("\n").presence
    end

    def subject_suffix
      return " (scholarship now requested)" if @notes.include?(SCHOLARSHIP_REQUESTED)

      " (registration changed)" if @notes.any?
    end
  end
end
