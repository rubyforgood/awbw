module EventRegistrationServices
  # Moves a registrant's CE credit when they transfer events, keeping two records
  # so each event holds its own money (issue #1944):
  #   * the source keeps a paid $0-hours stub — its payments count at the original
  #     event, and it still surfaces in that event's CE searches;
  #   * the destination gets a live record carrying the hours and the outstanding
  #     balance, where new payments are received and the certificate is earned.
  # When the reg being transferred out is itself a transfer-in (a collapsing double
  # transfer, or a transfer back to the origin), its live record is relocated
  # forward instead of split again, so no third record ever appears.
  #
  # Runs inside the transfer transaction, after the destination is saved and before
  # a collapsing middle reg is destroyed (so its CE moves rather than cascades away).
  class TransferContinuingEducation
    def initialize(transferred_out:, destination:)
      @transferred_out = transferred_out
      @destination = destination
    end

    def call
      # Query the records directly rather than through the association: a collapsing
      # middle reg is destroyed right after this, and a loaded has_many cache would
      # make its dependent: :destroy sweep away the record we just moved forward.
      records = ContinuingEducationRegistration.where(event_registration_id: @transferred_out.id).to_a
      if @transferred_out.transferred_in?
        records.each { |ce| relocate(ce) }
      else
        records.each { |ce| split(ce) }
      end
    end

    private

    # Collapse / back-to-origin: the reg being dropped already holds the live
    # record, so move it to the destination — merging into the destination's stub
    # for that license when one exists (transferring back to the origin restores it).
    def relocate(ce)
      existing = destination_ce_for(ce.professional_license_id)
      existing ? merge_into(existing, ce) : ce.update!(event_registration: @destination)
    end

    # Split one source CE into a paid stub here (hours zeroed, cost = the amount
    # already paid) plus a live record on the destination carrying the hours and
    # the outstanding balance. Skips creation if the destination already carries a
    # record for that license (the person was independently registered there).
    def split(ce)
      unless destination_ce_for(ce.professional_license_id)
        @destination.continuing_education_registrations.create!(
          professional_license_id: ce.professional_license_id,
          hours: ce.hours,
          cost_cents: ce.remaining_cost,
          skip_event_defaults: true
        )
      end
      ce.update!(hours: 0, cost_cents: ce.allocations_sum)
    end

    # Fold a relocated live record's hours, cost, and payments back into an existing
    # stub, then drop the now-empty relocated record. Restores the original single
    # record when transferring back to the origin.
    def merge_into(stub, ce)
      ce.allocations.each { |allocation| allocation.update!(allocatable: stub) }
      stub.update!(hours: ce.hours, cost_cents: stub.cost_cents.to_i + ce.cost_cents.to_i)
      ce.reload.destroy!
    end

    def destination_ce_for(license_id)
      @destination.continuing_education_registrations.detect { |ce| ce.professional_license_id == license_id }
    end
  end
end
