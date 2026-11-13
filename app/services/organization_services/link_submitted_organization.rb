module OrganizationServices
  # The shared core of the two org-linking editors (event registration and form
  # submission): given the org-related answers a person submitted (an "entry" —
  # org_name/position/website/organization_type/address), write them onto the
  # organization's profile and work address (a valid answer replaces what's saved;
  # the prior value stays in the Ahoy audit trail), create the job + facilitator
  # affiliations, and report what was saved, what it replaced, and what couldn't
  # be applied. The callers keep their
  # flow-specific wrappers: the registration flow's link row, pinning, and
  # autofill notes; the submission flow's metadata link.
  #
  # `entry` may be nil (an org linked by hand that no submission describes):
  # profile sync and conflict detection are skipped, but the affiliations are
  # still created — untitled, anchored to the org's sole address when it has one.
  class LinkSubmittedOrganization
    Result = Struct.new(:saved, :conflicts, :address, keyword_init: true) do
      # Flash notice naming the org and everything the form actually wrote onto
      # it. Flash messages render html_safe, so submitted text is escaped. `verb`
      # is the past tense ("linked" / "created and linked").
      def notice(organization:, verb:)
        text = "#{ERB::Util.html_escape(organization.name)} #{verb}."
        text += " Saved from the form: #{saved.map { |change| ERB::Util.html_escape(change.description) }.to_sentence}." if saved.any?
        text
      end

      # Flash warning naming the saved values the submission replaced (so the admin
      # can reapply any newer edits) and the answers that couldn't be applied, or
      # nil when there's neither.
      def warning(organization:)
        [ replaced_warning(organization), conflicts_warning(organization) ].compact.join(" ").presence
      end

      private

      def replaced_warning(organization)
        replaced = saved.select(&:update?)
        return if replaced.none?

        descriptions = replaced.map do |change|
          "#{ERB::Util.html_escape(change.description)} (was “#{ERB::Util.html_escape(change.previous_value)}”)"
        end
        "This submission replaced saved values on #{ERB::Util.html_escape(organization.name)}: #{descriptions.to_sentence}. " \
          "If anyone edited these since it was submitted, reapply their changes — the previous values are in the activity log."
      end

      def conflicts_warning(organization)
        return if conflicts.none?

        descriptions = conflicts.map do |conflict|
          "#{conflict.label} (#{ERB::Util.html_escape(conflict.summary)})"
        end
        "Some form answers weren't applied to #{ERB::Util.html_escape(organization.name)}: #{descriptions.to_sentence}. Edit the organization if they should change."
      end
    end

    # The four linking scenarios (ADR-0002 D2), derived per call — from the
    # form's role for a standalone submission (FormSubmission#linking_scenario)
    # or from the event for a registration (an on-demand facilitator training
    # shares the submission path's "on_demand" scenario). All but
    # non_facilitator_training confer the standing Facilitator affiliation; a
    # nil scenario (a non-agreement form) confers nothing.
    # Current.source while an admin links an org, so every write it makes is
    # stamped as coming from the link (FormSubmissionChanges badges those rows).
    CHANGE_SOURCE = "Organization linking".freeze

    FACILITATOR_CONFERRING_SCENARIOS = %w[on_demand facilitator_training reinstatement].freeze
    SCENARIOS = (FACILITATOR_CONFERRING_SCENARIOS + %w[non_facilitator_training]).freeze

    def self.call(person:, organization:, entry:, scenario:, training_date: nil, event_registration: nil)
      new(person:, organization:, entry:, scenario:, training_date:, event_registration:).call
    end

    def initialize(person:, organization:, entry:, scenario:, training_date: nil, event_registration: nil)
      @person = person
      @organization = organization
      @entry = entry
      @scenario = scenario
      @training_date = training_date
      @event_registration = event_registration
    end

    def call
      profile_changes = sync_profile
      address_result = upsert_address

      affiliation_changes = AffiliationServices::CreateFromRegistration.call(
        person: @person,
        organization: @organization,
        job_title: @entry && @entry[:position],
        training_date: @training_date,
        organization_address: address_result.address || sole_address,
        facilitator_training: FACILITATOR_CONFERRING_SCENARIOS.include?(@scenario),
        event_registration: @event_registration,
        repoint_address: address_result.address.present?
      )

      Result.new(saved: profile_changes + address_result.changes + affiliation_changes, conflicts: conflicts,
                 address: address_result.address)
    end

    private

    def sync_profile
      return [] unless @entry

      OrganizationServices::SyncProfile.call(
        organization: @organization, website: @entry[:website], organization_type: @entry[:organization_type],
        submission: @entry[:submission]
      ).changes
    end

    def upsert_address
      OrganizationServices::UpsertAddress.call(
        organization: @organization, **submitted_address
      )
    end

    # Computed after the sync + address upsert have run, so only the
    # genuinely-kept discrepancies remain.
    def conflicts
      return [] unless @entry

      ProfileDiff.for_entry(organization: @organization, entry: @entry)
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
