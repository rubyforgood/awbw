module OrganizationServices
  # Finds the existing organization a typed name means, tolerating the spelling
  # drift a spreadsheet carries: an exact (case-insensitive) name first, then the
  # same name ignoring punctuation ("Sample Org, Inc." / "sample org inc"), then the
  # same name ignoring a legal suffix ("Sample Org" / "Sample Org LLC"). A loose
  # match counts only when it points at a single organization. Names are indexed
  # once per instance, so one matcher serves a whole import.
  class NameMatcher
    Match = Data.define(:organization, :basis)

    def call(name)
      name = name.to_s.strip
      return if name.blank?

      exact = Organization.find_by(name: name)
      return Match.new(organization: exact, basis: :exact) if exact

      loose_match(:normalized, DuplicateFinder.normalized_name(name)) ||
        loose_match(:suffixless, DuplicateFinder.suffixless_name(name))
    end

    private

    def loose_match(basis, key)
      return if key.blank?

      ids = index[basis][key]
      Match.new(organization: Organization.find(ids.first), basis: basis) if ids&.one?
    end

    def index
      @index ||= Organization.pluck(:id, :name).each_with_object(normalized: {}, suffixless: {}) do |(id, name), keys|
        (keys[:normalized][DuplicateFinder.normalized_name(name)] ||= []) << id
        (keys[:suffixless][DuplicateFinder.suffixless_name(name)] ||= []) << id
      end
    end
  end
end
