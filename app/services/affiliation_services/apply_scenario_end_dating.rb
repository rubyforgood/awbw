module AffiliationServices
  # What an agreement scenario means for the person's *existing* affiliations,
  # applied when an admin links the submitted organization (ADR-0002 D3):
  #
  # - new_job: their active affiliations at OTHER organizations end — job and
  #   facilitator alike, they've left that org. The linked org's own rows are
  #   spared, and fresh job + facilitator affiliations are created after this
  #   runs, start-dated to the submission.
  # - every other scenario (on-demand, reinstatement, the event scenarios):
  #   nothing to end — reinstatement reconciles registration-style, creating
  #   affiliations only where no active one exists.
  #
  # Ends are dated the day before the agreement takes effect, so the newly
  # created affiliations (which start on the submission date) don't overlap —
  # and so a fresh Facilitator affiliation isn't skipped as a duplicate of a row
  # that would otherwise still count as active until the end of its last day.
  class ApplyScenarioEndDating
    def self.call(person:, organization:, scenario:, effective_date:)
      new(person:, organization:, scenario:, effective_date:).call
    end

    def initialize(person:, organization:, scenario:, effective_date:)
      @person = person
      @organization = organization
      @scenario = scenario
      @effective_date = effective_date
    end

    # Returns the affiliations it ended, so callers can report them and the
    # processing panel can flag them for correction.
    def call
      return [] unless @scenario == "new_job"

      end_affiliations(@person.affiliations.active_or_pending.where.not(organization: @organization))
    end

    private

    def end_affiliations(affiliations)
      affiliations.find_each.map do |affiliation|
        affiliation.update!(end_date: @effective_date - 1.day)
        affiliation
      end
    end
  end
end
