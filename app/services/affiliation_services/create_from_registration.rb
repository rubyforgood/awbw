module AffiliationServices
  # Creates the affiliations we want whenever a person registers for an event or
  # an admin links an organization to their registration:
  #
  #   1. a "job affiliation" with the title the person typed on their form, when
  #      one was provided, and
  #   2. a standing "facilitator affiliation" titled "Facilitator" — but ONLY for
  #      facilitator-training events (`facilitator_training: true`). A non-training
  #      registration still gets its job affiliation; we don't mint a facilitator
  #      affiliation off it, because being a facilitator is conferred by a training,
  #      not by any org-linked event. (Manual/historical facilitator affiliations
  #      are created directly, not through this service, so they're unaffected.)
  #
  # The facilitator affiliation is skipped only when the person already has an
  # active-or-pending affiliation titled exactly "Facilitator" with the
  # organization (a current one, or one dated to a future training that hasn't
  # started yet). An ended facilitator affiliation does NOT block a new one — a
  # returning facilitator gets a second affiliation with the new start date.
  # Because the job affiliation is created first, a job title of exactly
  # "Facilitator" satisfies that check, so we don't add a redundant duplicate. A
  # facilitator-ish job title that isn't exactly "Facilitator" (e.g. "Lead
  # Facilitator") still gets its own standing "Facilitator" affiliation alongside it.
  #
  # Start dates: the facilitator affiliation begins on the training date itself
  # (that's when they become a facilitator). The job affiliation is left without a
  # start date — we don't know when the person began that role (they may have been
  # with the org for years before this training), and dating it to registration
  # would misrepresent that.
  #
  # Returns an OrganizationServices::AutofillChange per existing affiliation it
  # re-pointed at the submitted organization address, so callers can report it.
  class CreateFromRegistration
    # repoint_address: false when organization_address is a fallback (the org's sole
    # address) rather than one the person submitted — it then only fills a blank.
    def self.call(person:, organization:, job_title: nil, training_date: nil, organization_address: nil, facilitator_training: true,
                  event_registration: nil, repoint_address: true)
      new(person:, organization:, job_title:, training_date:, organization_address:, facilitator_training:, event_registration:,
          repoint_address:).call
    end

    def initialize(person:, organization:, job_title: nil, training_date: nil, organization_address: nil, facilitator_training: true,
                   event_registration: nil, repoint_address: true)
      @person = person
      @organization = organization
      @job_title = job_title.presence&.strip
      @training_date = training_date
      @organization_address = organization_address
      @facilitator_training = facilitator_training
      @event_registration = event_registration
      @repoint_address = repoint_address
    end

    def call
      @repointed = []
      ActiveRecord::Base.transaction do
        create_job_affiliation
        create_facilitator_affiliation if @facilitator_training
      end
      @repointed
    end

    private

    def create_job_affiliation
      return unless @job_title

      existing = active_or_pending_affiliations_with_title(@job_title)
      return point_at_submitted_address(existing) if existing.exists?

      create_affiliation(@job_title, start_date: nil)
    end

    def create_facilitator_affiliation
      existing = active_or_pending_facilitator_affiliations
      return point_at_submitted_address(existing) if existing.exists?

      create_affiliation(Affiliation::FACILITATOR_TITLE, start_date: facilitator_start_date)
    end

    # An existing active-or-pending affiliation takes the address this submission
    # gave (the latest answer wins; the prior one stays in the Ahoy audit trail).
    # No-op when the submission carried no organization address.
    def point_at_submitted_address(affiliations)
      return unless @organization_address

      targets = affiliations.where(organization_address_id: nil)
      targets = targets.or(affiliations.where.not(organization_address_id: @organization_address.id)) if @repoint_address
      targets.includes(:organization_address).find_each do |affiliation|
        previous = affiliation.organization_address
        affiliation.update!(organization_address: @organization_address)
        @repointed << repointed_change(affiliation, previous)
      end
    end

    def repointed_change(affiliation, previous)
      OrganizationServices::AutofillChange.new(
        field: "affiliation_#{affiliation.id}_address", label: "#{affiliation.title} affiliation address",
        value: @organization_address.name.squish, previous_value: previous&.name&.squish
      )
    end

    def create_affiliation(title, start_date:)
      @person.affiliations.create!(
        organization: @organization,
        title: title,
        start_date: start_date,
        organization_address: @organization_address,
        event_registration: @event_registration
      )
    end

    def facilitator_start_date
      (@training_date || Date.current).to_date
    end

    def active_or_pending_affiliations_with_title(title)
      @person.affiliations.active_or_pending.where(organization: @organization, title: title)
    end

    # Uses the model's canonical `facilitators` scope (exactly "Facilitator",
    # trimmed and case-sensitive) so this agrees with #facilitator? and the rest of
    # the app on what counts as a facilitator affiliation. Counts pending
    # (future-dated) facilitator affiliations too, so registering for a second
    # upcoming training doesn't mint a duplicate.
    def active_or_pending_facilitator_affiliations
      @person.affiliations.active_or_pending.facilitators.where(organization: @organization)
    end
  end
end
