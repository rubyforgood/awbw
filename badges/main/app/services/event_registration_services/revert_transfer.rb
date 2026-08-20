module EventRegistrationServices
  # Undoes a transfer-out, restoring the registration to the status it held before
  # it was marked transferred out (or "registered" if none was captured).
  #
  # Pending (no destination recorded yet): just restore the status. Completed (a
  # destination reg already exists): also unlink that destination — it becomes a
  # normal standalone registration, nothing deleted — and re-merge its split CE
  # back onto this source before restoring the status. (#1944)
  class RevertTransfer
    def self.call(registration:) = new(registration:).call

    def initialize(registration:)
      @registration = registration
    end

    # Returns false (a no-op) if the reg isn't transferred out.
    def call
      return false unless @registration.transferred_out?

      ActiveRecord::Base.transaction do
        # Query directly rather than through the has_one: loading the association
        # would let the source's autosave re-link the destination when we update
        # the source's status below, undoing the unlink.
        destination = EventRegistration.find_by(transferred_from_registration_id: @registration.id)
        if destination
          TransferContinuingEducation.new(
            transferred_out: @registration, destination: destination
          ).revert
          destination.update!(transferred_from_registration: nil)
        end

        @registration.update!(status: restored_status, status_before_transfer: nil)
      end
      true
    end

    private

    def restored_status
      @registration.status_before_transfer.presence || "registered"
    end
  end
end
