class FormSubmissionDecorator < ApplicationDecorator
  delegate_all

  # Single best match for one attendee. Prefers first+last name match,
  # falls back to email match. Returns nil when no match is found.
  def best_match_for(attendee, event_registrations)
    first = attendee["first_name"]&.strip
    last = attendee["last_name"]&.strip
    email = attendee["email"]&.strip

    first_variants = first.present? ? NicknameMap.variants_for(first).to_set : Set.new
    normalized_last = last.present? ? NicknameMap.normalize(last) : nil

    event_registrations.find do |reg|
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
  end
end
