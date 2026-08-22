module OrganizationServices
  # The shared core of the two org-linking editors (event registration and form
  # submission): given the org-related answers a person submitted (an "entry" —
  # org_name/position/website/agency_type/address), fill the organization's
  # blank profile fields and work address from them (curated values are kept and
  # reported as conflicts instead), create the job + facilitator affiliations,
  # and report what was saved and what conflicted. The callers keep their
  # flow-specific wrappers: the registration flow's link row, pinning, and
  # autofill notes; the submission flow's metadata link.
  #
  # `entry` may be nil (an org linked by hand that no submission describes):
  # profile sync and conflict detection are skipped, but the affiliations are
  # still created — untitled, anchored to the org's sole address when it has one.
  class LinkSubmittedOrganization
    Result = Struct.new(:saved, :conflicts, :address, :ended_affiliations, keyword_init: true) do
      # Flash notice naming the org, everything the form actually wrote onto it,
      # and any affiliations the agreement scenario ended. Flash messages render
      # html_safe, so submitted text is escaped. `verb` is the past tense
      # ("linked" / "created and linked").
      def notice(organization:, verb:)
        text = "#{ERB::Util.html_escape(organization.name)} #{verb}."
        text += " Saved from the form: #{saved.map { |change| ERB::Util.html_escape(change.description) }.to_sentence}." if saved.any?
        if ended_affiliations.any?
          ended = ended_affiliations.map { |a| ERB::Util.html_escape("#{a.organization.name} (#{a.title.presence || "no title"})") }
          text += " Ended by this agreement: #{ended.to_sentence}."
        end
        text
      end

      # Flash warning listing the submitted answers that differ from values
      # already on the org (so the fill-blanks sync left them unapplied), or nil
      # when everything matched.
      def warning(organization:)
        return if conflicts.none?

        descriptions = conflicts.map do |conflict|
          "#{conflict.label} (form: “#{ERB::Util.html_escape(conflict.submitted)}”, saved: “#{ERB::Util.html_escape(conflict.saved)}”)"
        end
        "Some form answers differ from #{ERB::Util.html_escape(organization.name)}’s saved profile and were not applied: #{descriptions.to_sentence}. Edit the organization if they should change."
      end
    end

    def self.call(person:, organization:, entry:, facilitator_training:, training_date: nil, event_registration: nil, scenario: nil)
      new(person:, organization:, entry:, facilitator_training:, training_date:, event_registration:, scenario:).call
    end

    def initialize(person:, organization:, entry:, facilitator_training:, training_date: nil, event_registration: nil, scenario: nil)
      @person = person
      @organization = organization
      @entry = entry
      @facilitator_training = facilitator_training
      @training_date = training_date
      @event_registration = event_registration
      @scenario = scenario
    end

    def call
      ended_affiliations = apply_scenario_end_dating
      profile_changes = sync_profile
      address_result = upsert_address

      AffiliationServices::CreateFromRegistration.call(
        person: @person,
        organization: @organization,
        job_title: @entry && @entry[:position],
        training_date: @training_date,
        organization_address: address_result.address || sole_address,
        facilitator_training: @facilitator_training,
        event_registration: @event_registration
      )

      Result.new(saved: profile_changes + address_result.changes, conflicts: conflicts,
                 address: address_result.address, ended_affiliations: ended_affiliations)
    end

    private

    # An agreement scenario first settles the person's existing affiliations
    # (job change ends the other orgs'; reinstatement ends stale facilitator
    # rows) so the creations below start from the right state. Returns what it
    # ended.
    def apply_scenario_end_dating
      return [] unless @scenario

      AffiliationServices::ApplyScenarioEndDating.call(
        person: @person, organization: @organization, purpose: @scenario,
        effective_date: (@training_date || Date.current).to_date
      )
    end

    def sync_profile
      return [] unless @entry

      OrganizationServices::SyncProfile.call(
        organization: @organization, overwrite: false, website: @entry[:website], agency_type: @entry[:agency_type]
      ).changes
    end

    def upsert_address
      OrganizationServices::UpsertAddress.call(
        organization: @organization, overwrite: false, **submitted_address
      )
    end

    # Computed after the sync + address upsert have run, so only the
    # genuinely-kept discrepancies remain.
    def conflicts
      return [] unless @entry

      OrganizationServices::ProfileDiff.call(
        organization: @organization,
        website: @entry[:website],
        agency_type: @entry[:agency_type],
        address: submitted_address
      )
    end

    def submitted_address
      (@entry && @entry[:address]) || {}
    end

    # The org's single address, when it has exactly one — so a linked affiliation
    # can be anchored to it even if the person submitted no address.
    def sole_address
      addresses = @organization.addresses.active
      addresses.first if addresses.count == 1
    end
  end
end
