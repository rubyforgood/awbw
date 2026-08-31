class FormSubmissionDecorator < ApplicationDecorator
  delegate_all

  # The payer's display name/email. Prefer the linked person's account; fall
  # back to what the payer typed on the form — bulk-payment payers routinely
  # have no account, so `person` is nil — then a neutral placeholder for the name.
  def payer_name
    return object.person.name if object.person
    typed = [ answers_by_identifier["first_name"], answers_by_identifier["last_name"] ].compact_blank.join(" ")
    typed.presence || "Anonymous payer"
  end

  def payer_email
    return object.person.email if object.person
    answers_by_identifier["primary_email"].presence
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
