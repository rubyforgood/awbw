class FormSubmissionDecorator < ApplicationDecorator
  delegate_all

  # Formatted recipient invoice opens, oldest first, for the admin-only badge.
  def invoice_view_labels
    invoice_view_times.map { |time| InvoiceViewedLabel.for(time) }
  end

  def matched_attendees(event_registrations)
    object.bulk_payment_attendees.map do |attendee|
      first = attendee["first_name"]&.strip
      last = attendee["last_name"]&.strip
      email = attendee["email"]&.strip

      first_variants = first.present? ? NicknameMap.variants_for(first).to_set : Set.new
      normalized_last = last.present? ? NicknameMap.normalize(last) : nil

      matches = event_registrations.select do |reg|
        person = reg.registrant
        next false unless person

        first_matches = first_variants.include?(NicknameMap.normalize(person.first_name))
        last_matches = normalized_last.present? &&
                       NicknameMap.normalize(person.last_name) == normalized_last
        email_matches = email.present? && (
          person.email&.downcase == email.downcase ||
          person.email_2&.downcase == email.downcase
        )

        (first_matches && last_matches) || email_matches
      end

      { first_name: first, last_name: last, email: email, matches: matches }
    end
  end
end
