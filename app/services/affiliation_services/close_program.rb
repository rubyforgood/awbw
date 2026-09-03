module AffiliationServices
  # Processes a "close program" agreement (Form role close_program): the person
  # told us their AWBW program at an organization is ending. End-dates their
  # active-or-pending Facilitator affiliation(s) there to the effective date —
  # and their job affiliation(s) too when they're also leaving the job — and
  # leaves a comment on each recording why and as of when. The organization's
  # own status/dates re-derive from the Affiliation after-save callbacks, so
  # closing the last active facilitator flips the org Inactive automatically.
  #
  # Returns the affiliations it end-dated, so callers can report them (the flash
  # notice and the processing panel's "ended by this agreement" flag). Idempotent
  # in effect: a row already ended on or before the effective date isn't touched.
  class CloseProgram
    COMMENT_TOPIC = "Program closure".freeze

    def self.call(person:, organization:, effective_date:, reason: nil, leaving_job: false)
      new(person:, organization:, effective_date:, reason:, leaving_job:).call
    end

    def initialize(person:, organization:, effective_date:, reason: nil, leaving_job: false)
      @person = person
      @organization = organization
      @effective_date = (effective_date || Date.current).to_date
      @reason = reason.to_s.strip.presence
      @leaving_job = leaving_job
    end

    def call
      ActiveRecord::Base.transaction do
        ended = end_affiliations(facilitator_affiliations)
        ended += end_affiliations(job_affiliations) if @leaving_job
        ended
      end
    end

    private

    def facilitator_affiliations
      @person.affiliations.active_or_pending.facilitators.where(organization: @organization)
    end

    # Everything at the org that isn't the standing Facilitator affiliation — the
    # person's job affiliation(s), ended only when they say they're also leaving.
    def job_affiliations
      @person.affiliations.active_or_pending.where(organization: @organization)
        .where("affiliations.title IS NULL OR affiliations.title <> BINARY ?", Affiliation::FACILITATOR_TITLE)
    end

    def end_affiliations(affiliations)
      affiliations.find_each.map do |affiliation|
        affiliation.update!(end_date: @effective_date)
        note(affiliation)
        affiliation
      end
    end

    def note(affiliation)
      affiliation.comments.create!(
        topic: COMMENT_TOPIC,
        body: comment_body,
        created_by: Current.user,
        updated_by: Current.user
      )
    end

    def comment_body
      effective = @effective_date.to_fs(:long)
      base = "Program closed effective #{effective}."
      @reason ? "#{base} Reason: #{@reason}" : base
    end
  end
end
