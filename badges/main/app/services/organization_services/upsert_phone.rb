module OrganizationServices
  # Find-or-add an organization's phone from a registrant's submitted
  # organization_phone answer, mirroring UpsertAddress: a number the org already
  # holds (formatting aside) is reused and reactivated; a new one is added as a
  # work phone that becomes the org's primary (the latest answer wins), taking the
  # flag off the old primary — which stays on the org, reported as a change so
  # staff can switch back. A blank answer saves nothing.
  #
  # Shared by the public registration/form flow and the admin org-linking actions.
  class UpsertPhone
    # changes: AutofillChange per thing this call actually wrote — empty when the
    # answer was blank or the number was already the org's active primary.
    Result = Struct.new(:phone, :changes, keyword_init: true)

    def self.call(organization:, phone: nil)
      new(organization:, phone:).call
    end

    def initialize(organization:, phone: nil)
      @organization = organization
      @phone = phone&.strip
    end

    def call
      return Result.new(phone: nil, changes: []) if @phone.blank?

      existing = phones.find { |method| comparable(method.value) == comparable(@phone) }
      existing ? reuse(existing) : add
    end

    private

    def phones
      @organization.contact_methods.where(kind: :phone)
    end

    def comparable(value)
      ContactMethodDeduper.comparable_number(value.to_s)
    end

    def add
      previous_primaries = phones.where(primary: true).to_a
      previous_primaries.each { |phone| phone.update!(primary: false) }
      created = @organization.contact_methods.create!(kind: :phone, value: @phone, contact_type: "work", primary: true)
      changes = [ AutofillChange.new(field: "phone", label: "Phone", value: created.value) ]
      if (previous = previous_primaries.first)
        changes << AutofillChange.new(field: "primary_phone", label: "Primary phone", value: created.value,
                                      previous_value: previous.value)
      end
      Result.new(phone: created, changes: changes)
    end

    # A number already on file comes back into use: reactivated, and made primary
    # only when the org has no active primary phone (as UpsertAddress does for a
    # matched address), so resubmitting an old number doesn't displace the current one.
    # Reported only when that changed something, so a resubmission of the org's
    # current phone isn't claimed as a save.
    def reuse(existing)
      existing.primary = true if phones.where(primary: true, inactive: false).where.not(id: existing.id).none?
      existing.inactive = false
      changed = existing.changed?
      existing.save!
      changes = changed ? [ AutofillChange.new(field: "phone", label: "Phone", value: existing.value) ] : []
      Result.new(phone: existing, changes: changes)
    end
  end
end
