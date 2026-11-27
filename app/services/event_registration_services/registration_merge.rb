module EventRegistrationServices
  # Merging one registration into another — from the registrations deduper, or when a
  # people merge collapses two registrations for one event. ModelDeduper moves the rows;
  # this checks the merge is safe first and repairs what the move leaves pointing wrong.
  class RegistrationMerge
    CARRIED_TIMESTAMPS = %w[certificate_sent_at post_survey_completed_at].freeze

    def initialize(keep, delete)
      @keep = keep
      @delete = delete
    end

    def blocks
      [ open_checkout_block, attendance_overlap_block ].compact
    end

    # ticket_pickable: the registrations deduper lets the admin keep either ticket link; a people merge keeps the keeper's.
    def notes(ticket_pickable: false)
      return [] if @delete.slug.blank?
      return [ @delete.decorate.ticket_merge_note(ticket_emails(@delete).count) ] unless ticket_pickable

      [ EventRegistrationDecorator.ticket_choice_note([ @keep, @delete ].index_with { |registration| ticket_emails(registration).count }) ]
    end

    # Delivered emails to the registrant, or about this registration, that carried its ticket link.
    def ticket_emails(registration)
      return Notification.none if registration.slug.blank?

      sent = Notification.delivered
      sent.where(person_id: registration.registrant_id).or(sent.where(noticeable: registration)).matching(registration.slug)
    end

    # Run before ModelDeduper, while the deleted registration still holds its own rows.
    def prepare
      @delete_id = @delete.id
      @keep.filemaker_code = EventRegistration.join_filemaker_codes(@keep.filemaker_code, @delete.filemaker_code)
      @organization_pins = organization_pins
      self
    end

    # Attendance days and dates either copy has, so the merge keeps them; also prefills the deduper's keeper form.
    def carry_details
      (EventRegistration::DAY_FIELDS + CARRIED_TIMESTAMPS).each { |field| @keep[field] ||= @delete[field] }
      return unless @keep.changed.intersect?(EventRegistration::DAY_FIELDS) && @keep.status.in?(EventRegistration::ACTIVE_STATUSES)

      @keep.status = @keep.attendance_status_for_days
    end

    # Run after ModelDeduper, inside the merge transaction.
    def reconcile!
      recredit_scholarships
      ReconcileMergedContinuingEducation.new(@keep).call
      relink_bulk_payments
      restore_organization_pins
      unlink_other_registrants_affiliations
      days_changed = @keep.changed.intersect?(EventRegistration::DAY_FIELDS)
      @keep.save! if @keep.changed?
      @keep.sync_attendance_status_to_days! if days_changed
    end

    private

    # A Stripe charge names its registration in metadata; a late one for a deleted
    # registration finds nothing and records no payment.
    def open_checkout_block
      return unless @delete.checkout_session_id.present? && @delete.payment_unresolved.nil?

      "#{@delete.registrant&.full_name}'s registration has a Stripe checkout that hasn't finished. " \
        "Merge once it's paid, or once it's marked unresolved after a few days, so a late payment isn't lost."
    end

    def attendance_overlap_block
      days = clashing_attendance_days
      return if days.empty?

      "Both registrations have sign-in times on #{days.map { |day| day.strftime("%b %-d") }.to_sentence} " \
        "that overlap or add up to more than 24 hours. Remove the duplicate times on the attendance report before merging."
    end

    def clashing_attendance_days
      @delete.event_attendance_time_entries.filter_map do |entry|
        moved = EventAttendanceTimeEntry.new(event_registration_id: @keep.id,
          signed_in_at: entry.signed_in_at, signed_out_at: entry.signed_out_at)
        moved.attendance_date unless moved.valid?
      end.uniq.sort
    end

    # The org links both registrations hold collapse to the keeper's; carry the deleted
    # link's submission pin and autofill notes onto it when it has none.
    def organization_pins
      kept = @keep.event_registration_organizations.index_by(&:organization_id)
      @delete.event_registration_organizations.each_with_object({}) do |link, pins|
        survivor = kept[link.organization_id]
        next unless survivor

        fills = {}
        fills[:form_submission_id] = link.form_submission_id if survivor.form_submission_id.nil?
        fills[:form_autofill_changes] = link.read_attribute(:form_autofill_changes) if survivor.form_autofill_changes.empty?
        fills.compact_blank!
        pins[survivor.id] = fills if fills.any?
      end
    end

    def restore_organization_pins
      @organization_pins.each do |link_id, fills|
        EventRegistrationOrganization.find(link_id).update!(fills)
      end
    end

    def recredit_scholarships
      @keep.scholarships.where.not(recipient_id: @keep.registrant_id).find_each do |scholarship|
        scholarship.update!(recipient: @keep.registrant)
      end
    end

    def relink_bulk_payments
      FormSubmission.where("JSON_CONTAINS(metadata, ?, '$.linked_registration_ids')", @delete_id.to_s).find_each do |submission|
        submission.relink_registration!(@delete_id, @keep.id)
      end
    end

    # Affiliations the deleted registration minted belong to its registrant. Left on the
    # keeper, attendance and transfer changes would re-date another person's row; unlinked
    # they match deleting the registration (the FK nullifies).
    def unlink_other_registrants_affiliations
      Affiliation.where(event_registration_id: @keep.id).where.not(person_id: @keep.registrant_id)
        .update_all(event_registration_id: nil)
    end
  end
end
