module PersonServices
  # "anonymous" sets the profile's anonymous flag; any other credit preference clears it and becomes the name format.
  class ApplyAuthorCreditPreference
    def self.call(person:, preference:)
      new(person:, preference:).call
    end

    def initialize(person:, preference:)
      @person = person
      @preference = preference
    end

    def call
      return false unless @person && AuthorCreditable::AUTHOR_CREDIT_PREFERENCES.include?(@preference)

      if @preference == AuthorCreditable::ANONYMOUS
        @person.anonymous_contributions = true
      else
        @person.anonymous_contributions = false
        @person.display_name_preference = @preference
      end
      @person.save
    end
  end
end
