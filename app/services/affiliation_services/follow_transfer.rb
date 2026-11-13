module AffiliationServices
  # Moves a person's facilitator affiliation along with their registration when it
  # is transferred to another training (ADR-0003 D6d). Runs as part of the transfer
  # itself, so there is nothing to reconcile afterwards.
  #
  # Only the open row a moving registration created moves: it re-dates to the
  # destination event and re-points its provenance at the destination registration,
  # so reconciling the destination treats it as the row that training created. An
  # older or hand-entered row records facilitation that already happened and is left
  # alone, as is an ended row.
  #
  # `moved_only_from` registrations give up only rows an earlier transfer moved onto
  # them — a destination being unlinked keeps the row it created for itself.
  # `undo: true` words the note for a transfer being undone.
  class FollowTransfer
    # Comment topic marking a row a transfer moved, so undoing the transfer can tell
    # it apart from one the destination registration created itself.
    COMMENT_TOPIC = "Transfer".freeze

    def self.call(to:, from: [], moved_only_from: [], undo: false)
      new(to:, from:, moved_only_from:, undo:).call
    end

    def initialize(to:, from: [], moved_only_from: [], undo: false)
      @to = to
      @undo = undo
      @from = Array(from).compact.reject { |registration| registration.id == to.id }
      @moved_only_from = Array(moved_only_from).compact.reject { |registration| registration.id == to.id }
    end

    # Returns the affiliations it moved.
    def call
      # Only a training confers facilitation; undoing returns the row wherever it came from.
      return [] unless @undo || @to.event&.facilitator_training?

      movable.each { |affiliation| move(affiliation) }
    end

    private

    def movable
      rows = open_facilitator_rows(@from)
      rows += open_facilitator_rows(@moved_only_from).select { |affiliation| moved_by_transfer?(affiliation) }
      rows.uniq
    end

    # Only for organizations the destination links: re-dating an organization's row
    # to a training about another one would assert something false.
    def open_facilitator_rows(registrations)
      return [] if registrations.empty?

      Affiliation.facilitators
        .where(event_registration_id: registrations.map(&:id), end_date: nil, inactive: false)
        .where(organization_id: EventRegistrationOrganization.where(event_registration_id: @to.id).select(:organization_id))
        .includes(:comments, event_registration: :event)
        .to_a
    end

    def moved_by_transfer?(affiliation)
      affiliation.comments.any? { |comment| comment.topic == COMMENT_TOPIC }
    end

    def move(affiliation)
      starts_on = @to.event.starts_on || Date.current
      left = affiliation.event_registration&.event
      affiliation.update!(start_date: starts_on, event_registration: @to)
      affiliation.comments.create_as_system!(topic: COMMENT_TOPIC, body: note(affiliation, left, starts_on))
    end

    def note(affiliation, left, starts_on)
      moved = "#{@to.event.title} (starting #{starts_on.strftime('%b %-d, %Y')})"
      return "Moved back to #{moved} when the transfer#{" to #{left.title}" if left} was undone." if @undo

      "Moved to #{moved} when #{affiliation.person.name} transferred#{" out of #{left.title}" if left}."
    end
  end
end
