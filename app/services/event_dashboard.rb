class EventDashboard
  def initialize(event)
    @event = event
  end

  attr_reader :event

  def registrant_count
    active_registration_ids.size
  end

  # Cancelled / no-show registrations.
  def inactive_registration_count
    event.event_registrations.where(status: EventRegistration::INACTIVE_STATUSES).count
  end

  # Active registrants as Person records, ordered by display name.
  def registrants
    @registrants ||= people_sorted(registrant_ids)
  end

  def scholarship_total_cents
    scholarships.sum(:amount_cents)
  end

  def scholarship_recipient_count
    scholarships.distinct.count(:recipient_id)
  end

  # Scholarships whose tasks are done (their dollars are applied) vs still
  # outstanding (awarded but not yet applied).
  def completed_scholarship_cents
    completed_scholarships.sum(:amount_cents)
  end

  def outstanding_scholarship_cents
    outstanding_scholarships.sum(:amount_cents)
  end

  def completed_scholarship_registrants
    @completed_scholarship_registrants ||= people_sorted(completed_scholarships.distinct.pluck(:recipient_id))
  end

  def outstanding_scholarship_registrants
    @outstanding_scholarship_registrants ||= people_sorted(outstanding_scholarships.distinct.pluck(:recipient_id))
  end

  # Real money allocated to this event's registrations from payments.
  def received_cents
    registration_allocations.where(source_type: "Payment").sum(:amount)
  end

  # Still owed across all active registrations, after payments and scholarships.
  def outstanding_cents
    active_registration_ids.sum do |id|
      [ event.cost_cents.to_i - allocated_by_registration.fetch(id, 0), 0 ].max
    end
  end

  # Full-price value of all active registrations (before scholarships/discounts).
  def total_cents
    event.cost_cents.to_i * registrant_count
  end

  # Registration-fee subtotal: money received plus money still owed. This is the
  # cash side of registration fees (it excludes scholarship-covered cost), so it
  # reconciles with the Paid + Due breakdown and the grand-total equation.
  # Differs from total_cents, the full pre-scholarship price.
  def registration_subtotal_cents
    received_cents + outstanding_cents
  end

  # Everything accounted for: registration fees (received + still owed),
  # scholarships awarded, and continuing-education fees.
  def grand_total_cents
    registration_subtotal_cents + scholarship_total_cents + cont_ed_total_cents
  end

  def paid_count
    return registrant_count if free?
    active_registration_ids.count { |id| allocated_by_registration.fetch(id, 0) >= event.cost_cents.to_i }
  end

  def unpaid_count
    return 0 if free?
    registrant_count - paid_count
  end

  # Registrants whose cost is fully covered (payments and/or completed
  # scholarships) vs those still owing.
  def paid_registrants
    @paid_registrants ||= people_sorted(registrants_for(paid_registration_ids))
  end

  def unpaid_registrants
    @unpaid_registrants ||= people_sorted(registrants_for(active_registration_ids - paid_registration_ids))
  end

  # Continuing-education fee: a flat per-registrant add-on. Not yet implemented —
  # the fee amount and per-registration paid/outstanding tracking will arrive
  # with a future migration. Stubbed to zero so the dashboard renders the
  # section without depending on columns that don't exist yet.
  def cont_ed_fee_cents = 0
  def cont_ed_total_cents = 0
  def cont_ed_paid_count = 0
  def cont_ed_unpaid_count = 0
  def cont_ed_paid_cents = 0
  def cont_ed_outstanding_cents = 0
  def cont_ed_paid_registrants = []
  def cont_ed_unpaid_registrants = []

  def free?
    event.cost_cents.to_i <= 0
  end

  # Unique orgs from both the snapshot taken at registration time and the
  # registrants' currently-active affiliations.
  def organizations
    @organizations ||= Organization.where(id: organization_ids).order(:name)
  end

  def organization_count
    organization_ids.size
  end

  # Distinct registrant ids per organization, across the registration-time
  # snapshot and registrants' currently-active affiliations.
  def organization_registrant_ids_by_org
    @organization_registrant_ids_by_org ||= begin
      snapshot = EventRegistrationOrganization
        .joins(:event_registration)
        .where(event_registration_id: active_registration_ids)
        .pluck(:organization_id, "event_registrations.registrant_id")
      affiliated = Affiliation.active
        .where(person_id: registrant_ids)
        .pluck(:organization_id, :person_id)
      (snapshot + affiliated).each_with_object(Hash.new { |hash, key| hash[key] = Set.new }) do |(organization_id, person_id), map|
        map[organization_id] << person_id if organization_id
      end
    end
  end

  # Distinct registrant count per organization.
  def organization_counts
    @organization_counts ||= organization_registrant_ids_by_org.transform_values(&:size)
  end

  # Registrant ids tied to at least one organization — the people behind the
  # organizations count.
  def organization_registrant_ids
    @organization_registrant_ids ||= organization_registrant_ids_by_org.values.flat_map(&:to_a).uniq
  end

  def sectors
    @sectors ||= Sector.where(id: registrant_sector_ids).order(:name)
  end

  # Distinct registrant count per sector.
  def sector_counts
    @sector_counts ||= SectorableItem
      .where(sectorable_type: "Person", sectorable_id: registrant_ids)
      .distinct
      .group(:sector_id)
      .count(:sectorable_id)
  end

  # Registrant ids that belong to at least one sector — the people behind the
  # sectors count.
  def sector_registrant_ids
    @sector_registrant_ids ||= SectorableItem
      .where(sectorable_type: "Person", sectorable_id: registrant_ids)
      .distinct
      .pluck(:sectorable_id)
  end

  def states
    @states ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(state: [ nil, "" ])
      .distinct
      .pluck(:state)
      .sort
  end

  # Distinct registrant count per state.
  def state_counts
    @state_counts ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(state: [ nil, "" ])
      .group(:state)
      .distinct
      .count(:addressable_id)
  end

  # Registrant ids that have at least one active address with a state on file —
  # i.e. the people behind the states count.
  def state_registrant_ids
    @state_registrant_ids ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(state: [ nil, "" ])
      .distinct
      .pluck(:addressable_id)
  end

  # Distinct [ state, county ] pairs across active registrants' active addresses,
  # sorted by state then county. Pairing in the state lets the manage filter
  # disambiguate same-named counties across states (e.g. "CA - Warren" vs
  # "NY - Warren").
  def counties
    @counties ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(county: [ nil, "" ])
      .where.not(state: [ nil, "" ])
      .distinct
      .pluck(:state, :county)
      .sort
  end

  private

  def active_registrations
    @active_registrations ||= event.event_registrations.active
  end

  def active_registration_ids
    @active_registration_ids ||= active_registrations.pluck(:id)
  end

  def registrant_ids
    @registrant_ids ||= active_registrations.pluck(:registrant_id)
  end

  def registration_allocations
    Allocation.where(allocatable_type: "EventRegistration", allocatable_id: active_registration_ids)
  end

  def allocated_by_registration
    @allocated_by_registration ||= registration_allocations.group(:allocatable_id).sum(:amount)
  end

  def scholarships
    @scholarships ||= Scholarship
      .joins(:allocation)
      .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: active_registration_ids })
  end

  def completed_scholarships
    scholarships.where(tasks_completed: true)
  end

  def outstanding_scholarships
    scholarships.where(tasks_completed: false)
  end

  def paid_registration_ids
    @paid_registration_ids ||= active_registration_ids.select do |id|
      allocated_by_registration.fetch(id, 0) >= event.cost_cents.to_i
    end
  end

  def registrant_id_by_registration
    @registrant_id_by_registration ||= active_registrations.pluck(:id, :registrant_id).to_h
  end

  def registrants_for(registration_ids)
    registration_ids.filter_map { |id| registrant_id_by_registration[id] }
  end

  def people_sorted(person_ids)
    Person.where(id: person_ids).sort_by(&:name)
  end

  def organization_ids
    @organization_ids ||= begin
      snapshot_ids = EventRegistrationOrganization
        .where(event_registration_id: active_registration_ids)
        .pluck(:organization_id)
      affiliated_ids = Affiliation.active
        .where(person_id: registrant_ids)
        .pluck(:organization_id)
      (snapshot_ids + affiliated_ids).compact.uniq
    end
  end

  def registrant_sector_ids
    @registrant_sector_ids ||= SectorableItem
      .where(sectorable_type: "Person", sectorable_id: registrant_ids)
      .distinct
      .pluck(:sector_id)
  end
end
