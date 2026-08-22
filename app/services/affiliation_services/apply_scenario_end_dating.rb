module AffiliationServices
  # What an agreement scenario (Form::PURPOSES) means for the person's existing
  # affiliations, applied when an admin links the submitted organization:
  #
  # - job change: their active affiliations at OTHER organizations end — job and
  #   facilitator alike, they've left that org. The linked org's own rows are
  #   spared (they may already be affiliated there).
  # - reinstatement: any still-active Facilitator affiliations end (a returning
  #   facilitator shouldn't have one — this trues up the data), while job
  #   affiliations are left alone everywhere.
  # - on-demand (and unpurposed forms): nothing to end.
  #
  # Ends are dated the day before the agreement takes effect, so the newly
  # created affiliations (which start on the submission date) don't overlap —
  # and so a fresh Facilitator affiliation isn't skipped as a duplicate of a row
  # that would otherwise still count as active until the end of its last day.
  class ApplyScenarioEndDating
    def self.call(person:, organization:, purpose:, effective_date:)
      new(person:, organization:, purpose:, effective_date:).call
    end

    def initialize(person:, organization:, purpose:, effective_date:)
      @person = person
      @organization = organization
      @purpose = purpose
      @effective_date = effective_date
    end

    # Returns the affiliations it ended, so callers can report them and the
    # processing panel can flag them for correction.
    def call
      case @purpose
      when "job_change"
        end_affiliations(@person.affiliations.active_or_pending.where.not(organization: @organization))
      when "reinstatement"
        end_affiliations(@person.affiliations.active_or_pending.facilitators)
      else
        []
      end
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
