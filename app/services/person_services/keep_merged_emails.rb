module PersonServices
  # Carries a merged-away person's emails onto the kept person: the first one the keeper
  # doesn't already hold fills an empty email 2, and any that don't fit go in a comment.
  class KeepMergedEmails
    Email = Data.define(:address, :type)

    def initialize(person, merged:)
      @person = person
      @merged = merged
    end

    def missing
      [ Email.new(@merged.email, @merged.email_type), Email.new(@merged.email_2, @merged.email_2_type) ]
        .select { |email| email.address.present? && !PlaceholderEmail.match?(email.address) }
        .reject { |email| held?(email.address) }
        .uniq { |email| email.address.downcase }
    end

    def call
      missing = self.missing
      return if missing.empty?

      if @person.email_2.blank?
        kept = missing.shift
        @person.assign_attributes(email_2: kept.address, email_2_type: kept.type)
      end
      note_unplaced(missing) if missing.any?
    end

    private

    def held?(address)
      [ @person.email, @person.email_2 ].any? { |held| held.to_s.casecmp?(address) }
    end

    def note_unplaced(emails)
      @person.comments.create!(
        topic: "Email from merged person",
        body: "#{emails.map(&:address).to_sentence} came from #{@merged.full_name}, who was merged into this person, " \
              "and didn't fit in email 2 (#{@person.email_2}), so #{emails.one? ? "it is" : "they are"} recorded here."
      )
    end
  end
end
