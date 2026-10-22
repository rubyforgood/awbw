module AffiliationServices
  # Someone left their job for a new organization: their active-or-pending
  # affiliations everywhere else (or only at the `only:` organizations) end, job
  # and facilitator alike. Ends are dated the day before the new one starts
  # (ADR-0002 D4) so old and new rows never overlap.
  # Returns the affiliations it ended so callers can report them.
  class EndOtherOrganizations
    def self.call(person:, organization:, effective_date:, only: nil)
      new(person:, organization:, effective_date:, only:).call
    end

    def initialize(person:, organization:, effective_date:, only: nil)
      @person = person
      @organization = organization
      @effective_date = effective_date.to_date
      @only = only
    end

    def call
      affiliations = @person.affiliations.active_or_pending.where.not(organization: @organization)
      affiliations = affiliations.where(organization_id: @only) if @only
      affiliations.find_each.map do |affiliation|
        affiliation.update!(end_date: @effective_date - 1.day)
        affiliation
      end
    end
  end
end
