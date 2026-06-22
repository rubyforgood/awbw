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

  # Registrant (Person) ids behind the inactive (cancelled / no-show)
  # registrations — for drilling into the matching manage list.
  def inactive_registrant_ids
    @inactive_registrant_ids ||= event.event_registrations
      .where(status: EventRegistration::INACTIVE_STATUSES)
      .distinct
      .pluck(:registrant_id)
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

  # Field identifiers for the scholarship-application questions, wherever they
  # are asked (the scholarship section can live on the registration form, the
  # standalone scholarship form, or both).
  SCHOLARSHIP_ANSWER_IDENTIFIERS = FormBuilderService::SECTION_FIELD_IDENTIFIERS[:scholarship].freeze

  # Professional-info answers shown in each recipient's header. The view falls
  # back to the person's profile (sectors / age-range tags) when these aren't on
  # file as form answers. Sector answers are normalized under the "sector" key
  # (see #header_answers_by_applicant) so the view reads one key regardless of
  # which sector field identifier the answer was stored under.
  HEADER_ANSWER_IDENTIFIERS = (FormField::ADDITIONAL_SECTOR_FIELD_IDENTIFIERS + %w[primary_age_group]).freeze

  # The key sector answers are filed under in the per-applicant header hash.
  HEADER_SECTOR_KEY = "sector".freeze

  # Active registrants who requested a scholarship for this event, as Person
  # records sorted by display name. Sectors, age-range tags, and affiliations are
  # preloaded for the recipients page header; their application answers appear
  # below it.
  def scholarship_applicants
    @scholarship_applicants ||= Person
      .where(id: scholarship_applicant_ids)
      .includes(:sectors, { categories: :category_type },
                { categorizable_items: { category: :category_type } },
                { affiliations: :organization })
      .sort_by(&:name)
  end

  # Scholarship-application answers for this event's applicants, keyed by Person
  # id and de-duplicated to one answer per question. The scholarship section may
  # be captured on the registration submission (registered with scholarship
  # requested), a separate scholarship submission, or both, so this gathers by
  # field identifier across every form submission the registrant made for this
  # event — surfacing the answers wherever they live.
  def scholarship_answers_by_applicant
    @scholarship_answers_by_applicant ||= applicant_answers_for(SCHOLARSHIP_ANSWER_IDENTIFIERS)
      .transform_values { |answers| dedupe_answers(answers) }
  end

  # Sector / primary_age_group answers for the recipients page header, keyed by
  # Person id then by header key (one answer each). Sector answers (whichever
  # sector field identifier they used) are filed under HEADER_SECTOR_KEY so the
  # view reads a single, stable key. Same cross-submission gathering as
  # scholarship_answers_by_applicant.
  def header_answers_by_applicant
    @header_answers_by_applicant ||= applicant_answers_for(HEADER_ANSWER_IDENTIFIERS)
      .transform_values { |answers| answers.index_by { |answer| header_answer_key(answer.form_field&.field_identifier) } }
  end

  # Normalizes a header answer's field identifier to its lookup key: every sector
  # field collapses to HEADER_SECTOR_KEY; other identifiers pass through.
  def header_answer_key(identifier)
    identifier.in?(FormField::SECTOR_FIELD_IDENTIFIERS) ? HEADER_SECTOR_KEY : identifier
  end

  # A "shout out": a registrant the admin opted in (shoutout on their
  # registration) paired with the shout-out text from their profile and their
  # affiliated organization (if any), for the recognition block on the
  # recipients page.
  Shoutout = Struct.new(:recipient, :organization, :text, :sector, :age_group, keyword_init: true)

  # Shout outs for the recipients page: each active registrant the admin flagged
  # for a shout-out who also has shout-out text on their profile, paired with that
  # text, their first active affiliated organization (if any), and their primary
  # sector / age group (from their profile) for the parenthetical after their name.
  # Flagged registrants with blank shout-out text are omitted; org/sector/age are optional.
  def shoutouts
    @shoutouts ||= shoutout_registrants.filter_map do |person|
      text = person.shoutout_text.to_s.strip.presence
      next unless text
      organization = person.affiliations.reject(&:inactive?).filter_map(&:organization).first
      Shoutout.new(
        recipient: person,
        organization: organization,
        text: text,
        sector: primary_sector_name_for(person),
        age_group: age_group_text_for(person)
      )
    end
  end

  # The scholarship record per recipient, keyed by Person id — lets the roster
  # decide whether to flag a registrant as a scholarship recipient. First
  # scholarship wins if a person has several.
  def scholarship_by_recipient
    @scholarship_by_recipient ||= scholarships.includes(grant: :donor).group_by(&:recipient_id).transform_values(&:first)
  end

  # Active registration slug per registrant (Person id) — a stable, non-db
  # participant identifier used to anchor a registrant's entry on the recipients
  # page and to link to it from the roster. One active registration per event.
  def registration_slug_by_registrant
    @registration_slug_by_registrant ||= active_registrations.pluck(:registrant_id, :slug).to_h
  end

  def scholarship_registrants
    @scholarship_registrants ||= people_sorted(scholarships.distinct.pluck(:recipient_id))
  end

  def scholarship_amounts_by_recipient
    @scholarship_amounts_by_recipient ||= scholarships.group(:recipient_id).sum(:amount_cents)
  end

  # Per-registrant payment-sourced cents received, keyed by Person id. Aggregates
  # across a person's registrations; sums to received_cents.
  def registration_paid_by_registrant
    @registration_paid_by_registrant ||= registration_allocations
      .where(source_type: "Payment")
      .group(:allocatable_id)
      .sum(:amount)
      .each_with_object(Hash.new(0)) do |(registration_id, cents), map|
        registrant_id = registrant_id_by_registration[registration_id]
        map[registrant_id] += cents if registrant_id
      end
  end

  # Per-registrant cents still owed after payments and scholarships, keyed by
  # Person id. Aggregates across a person's registrations; sums to outstanding_cents.
  def registration_due_by_registrant
    @registration_due_by_registrant ||= active_registration_ids.each_with_object(Hash.new(0)) do |id, map|
      due = [ event.cost_cents.to_i - allocated_by_registration.fetch(id, 0), 0 ].max
      next if due.zero?
      registrant_id = registrant_id_by_registration[id]
      map[registrant_id] += due if registrant_id
    end
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

  def grand_total_cents
    registration_subtotal_cents + scholarship_total_cents + cont_ed_total_cents + unallocated_bulk_payment_cents
  end

  # Money received through this event's bulk payment submissions that hasn't been
  # allocated to a registration yet — cash on hand still waiting to be applied.
  def unallocated_bulk_payment_cents
    bulk_payments.sum(:amount_cents_remaining)
  end

  # Cash actually collected from registrants: registration payments received plus
  # continuing-education fees paid. Excludes scholarships, which are awarded, not
  # collected. With due_cents this sums to monies_made_cents.
  def collected_cents
    received_cents + cont_ed_paid_cents
  end

  # Money still owed across registration fees and continuing-education fees.
  def due_cents
    outstanding_cents + cont_ed_outstanding_cents
  end

  # Fee revenue the org earns: registration fees plus continuing-education fees,
  # paid or not (collected + due). Excludes scholarship-covered cost, which isn't
  # money made.
  def monies_made_cents
    registration_subtotal_cents + cont_ed_total_cents
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

  # Every organization represented at this event (the same set counted by
  # organization_count) bucketed as :new, :ongoing, or :reinstated — so the three
  # buckets always total organization_count. Each org is classified by its
  # facilitator history, using the registrant's own (earliest) affiliation to it
  # as the reference when present, otherwise the org's earliest facilitator
  # affiliation; an org with no facilitator history at all counts as :new.
  def program_status_counts
    @program_status_counts ||= organizations.each_with_object({ new: 0, ongoing: 0, reinstated: 0 }) do |organization, counts|
      counts[program_status_for(organization)] += 1
    end
  end

  # Program status (:new / :ongoing / :reinstated) per represented organization,
  # keyed by organization id — the same classification as program_status_counts.
  def program_status_by_organization
    @program_status_by_organization ||= organizations.to_h { |organization| [ organization.id, program_status_for(organization) ] }
  end

  # Distinct program statuses for each registrant's organization(s), keyed by
  # Person id — for the registrant roster's program-status column.
  def program_statuses_by_registrant
    @program_statuses_by_registrant ||= organization_ids_by_registrant.transform_values do |organization_ids|
      organization_ids.filter_map { |organization_id| program_status_by_organization[organization_id] }.uniq
    end
  end

  # Organization ids per registrant (Person id) — the inverse of
  # organization_registrant_ids_by_org.
  def organization_ids_by_registrant
    @organization_ids_by_registrant ||= organization_registrant_ids_by_org
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(organization_id, person_ids), map|
        person_ids.each { |person_id| map[person_id] << organization_id }
      end
  end

  # Distinct registrant ids per organization, across the registration-time
  # snapshot and registrants' currently-active affiliations.
  def organization_registrant_ids_by_org
    @organization_registrant_ids_by_org ||= begin
      snapshot = EventRegistrationOrganization
        .joins(:event_registration)
        .where(event_registration_id: active_registration_ids)
        .pluck(:organization_id, "event_registrations.registrant_id")
      affiliated = Affiliation.active_or_pending
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

  # Organization names per registrant id (Person id), for registrant tooltips.
  # Built from the same snapshot + active-affiliation data as the organizations
  # breakdown, so the names match the Organizations count.
  def organization_names_by_registrant
    @organization_names_by_registrant ||= begin
      names_by_id = organizations.index_by(&:id)
      organization_registrant_ids_by_org.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(organization_id, person_ids), map|
        organization = names_by_id[organization_id]
        next unless organization
        person_ids.each { |person_id| map[person_id] << organization.name }
      end
    end
  end

  # A short location label per registrant id: the US state abbreviation for
  # domestic addresses, or the country's ISO 3-letter code for international ones
  # (e.g. "CA", "CAN"). Built from each registrant's active address, preferring
  # the primary one. Registrants without an address on file are omitted.
  def location_label_by_registrant
    @location_label_by_registrant ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .order(primary: :desc, updated_at: :desc)
      .pluck(:addressable_id, :state, :country)
      .each_with_object({}) do |(person_id, state, country), map|
        next if map.key?(person_id)
        label = location_label(state, country)
        map[person_id] = label if label.present?
      end
  end

  # Every sector tagged on registrants (primary + additional), backing the
  # "All sectors" chart. The "Primary sector" chart instead uses
  # #primary_sectors / #primary_sector_counts, which read only the dropdown.
  def sectors
    @sectors ||= Sector.where(id: registrant_sector_ids).order(:name)
  end

  # Sectors registrants named as their single primary sector (the
  # registration dropdown), ordered for the "Primary sector" chart.
  def primary_sectors
    @primary_sectors ||= Sector.where(id: primary_sector_counts.keys).order(:name)
  end

  # Distinct-registrant count per sector named as the primary sector.
  def primary_sector_counts
    @primary_sector_counts ||= primary_sector_registrant_ids_by_sector.transform_values(&:size)
  end

  # Registrant ids per primary sector, for the chart's per-row drill-in links.
  def primary_sector_registrant_ids_by_sector
    @primary_sector_registrant_ids_by_sector ||= primary_sector_rows
      .group_by(&:last)
      .transform_values { |rows| rows.map(&:first).uniq }
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

  # Distinct sectors registrants named as their primary sector, and distinct
  # sectors that appear as an additional (non-primary) tag. These OVERLAP — a
  # sector can be primary for one registrant and additional for another, so the
  # two counts can each be up to the sectors total and may sum to more than it.
  def primary_sector_count
    primary_sector_ids.size
  end

  def additional_sector_count
    additional_sector_ids.size
  end

  # Primary age group(s) served, read from registrants' answers to the
  # registration form's "primary_age_group" question (each answer stores the
  # chosen AgeRange category ids, ", "-joined). Resolved to AgeRange categories,
  # ordered by position then name.
  def age_groups
    @age_groups ||= Category.age_ranges
      .where(id: age_group_counts.keys)
      .ordered_by_position_and_name
  end

  # Distinct registrant count per age-group category, from registration responses.
  # Keyed by Category id, so it pairs with age_groups for the view.
  def age_group_counts
    @age_group_counts ||= age_group_answer_rows
      .group_by(&:last)
      .transform_values { |rows| rows.map(&:first).uniq.size }
  end

  # Registrant ids who answered the primary age group question.
  def age_group_registrant_ids
    @age_group_registrant_ids ||= age_group_answer_rows.map(&:first).uniq
  end

  # Registrant ids per age-group category, keyed by Category id — the people
  # behind each age-group row, for drilling into the matching registrant list.
  def age_group_registrant_ids_by_category
    @age_group_registrant_ids_by_category ||= age_group_answer_rows
      .group_by(&:last)
      .transform_values { |rows| rows.map(&:first).uniq }
  end

  # US states only — international registrants' regions (e.g. provinces) are
  # excluded so the States breakdown reflects domestic residents.
  def states
    @states ||= us_state_addresses.distinct.pluck(:state).sort
  end

  # Distinct US-resident registrant count per state.
  def state_counts
    @state_counts ||= us_state_addresses.group(:state).distinct.count(:addressable_id)
  end

  # Registrant ids that have at least one active US address with a state on file —
  # i.e. the people behind the states count.
  def state_registrant_ids
    @state_registrant_ids ||= us_state_addresses.distinct.pluck(:addressable_id)
  end

  def countries
    @countries ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(country: [ nil, "" ])
      .distinct
      .pluck(:country)
      .sort
  end

  # Distinct registrant count per country.
  def country_counts
    @country_counts ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(country: [ nil, "" ])
      .group(:country)
      .distinct
      .count(:addressable_id)
  end

  # Registrant ids that have at least one active address with a country on file.
  def country_registrant_ids
    @country_registrant_ids ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(country: [ nil, "" ])
      .distinct
      .pluck(:addressable_id)
  end

  # School districts on file across active registrants' active addresses
  # (Address#district), sorted by name.
  def school_districts
    @school_districts ||= district_addresses.distinct.pluck(:district).sort
  end

  # Distinct registrant count per school district.
  def school_district_counts
    @school_district_counts ||= district_addresses.group(:district).distinct.count(:addressable_id)
  end

  # Registrant ids that have at least one active address with a school district.
  def school_district_registrant_ids
    @school_district_registrant_ids ||= district_addresses.distinct.pluck(:addressable_id)
  end

  # Registrant ids per country, keyed by country name — the people behind each
  # country row, for drilling into the matching registrant list.
  def country_registrant_ids_by_country
    @country_registrant_ids_by_country ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(country: [ nil, "" ])
      .distinct
      .pluck(:country, :addressable_id)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }
  end

  # Registrant ids per school district, for the breakdown's per-row drill-in.
  def school_district_registrant_ids_by_district
    @school_district_registrant_ids_by_district ||= district_addresses
      .distinct
      .pluck(:district, :addressable_id)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }
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

  # Life experiences captured at registration: StoryPopulation categories tagged
  # onto registrants. Ordered by name.
  def life_experiences
    @life_experiences ||= Category.where(id: registrant_life_experience_ids).order(:name)
  end

  # Distinct registrant count per life-experience category, keyed by Category id.
  def life_experience_counts
    @life_experience_counts ||= life_experience_items
      .distinct
      .group(:category_id)
      .count(:categorizable_id)
  end

  # Registrant ids tagged with at least one life experience.
  def life_experience_registrant_ids
    @life_experience_registrant_ids ||= life_experience_items.distinct.pluck(:categorizable_id)
  end

  # Registrant ids per life-experience category, keyed by Category id — the
  # people behind each row, for drilling into the matching registrant list.
  def life_experience_registrant_ids_by_category
    @life_experience_registrant_ids_by_category ||= life_experience_items
      .distinct
      .pluck(:category_id, :categorizable_id)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }
  end

  # Workshop settings captured at registration: WorkshopEnvironment categories
  # tagged onto registrants. Ordered by name.
  def settings
    @settings ||= Category.where(id: registrant_settings_ids).order(:name)
  end

  # Distinct registrant count per setting category, keyed by Category id.
  def settings_counts
    @settings_counts ||= settings_items
      .distinct
      .group(:category_id)
      .count(:categorizable_id)
  end

  # Registrant ids tagged with at least one workshop setting.
  def settings_registrant_ids
    @settings_registrant_ids ||= settings_items.distinct.pluck(:categorizable_id)
  end

  # Registrant ids per setting category, keyed by Category id — the people behind
  # each row, for drilling into the matching registrant list.
  def settings_registrant_ids_by_category
    @settings_registrant_ids_by_category ||= settings_items
      .distinct
      .pluck(:category_id, :categorizable_id)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }
  end

  private

  # USPS abbreviations for the 50 states, DC, and the territories the US atlas
  # draws. The States breakdown only shows these, so international registrants'
  # regions (e.g. "ON", "England") are excluded — those belong to the Countries map.
  US_STATE_ABBREVIATIONS = %w[
    AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO
    MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY
    PR GU VI AS MP
  ].freeze

  # Active registrant addresses whose state is a recognized US state/territory —
  # the source for every States figure (count card, choropleth, and drill-in).
  def us_state_addresses
    Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where("UPPER(addresses.state) IN (?)", US_STATE_ABBREVIATIONS)
  end

  def district_addresses
    Address
      .active
      .where(addressable_type: "Person", addressable_id: registrant_ids)
      .where.not(district: [ nil, "" ])
  end

  def active_registrations
    @active_registrations ||= event.event_registrations.active
  end

  def active_registration_ids
    @active_registration_ids ||= active_registrations.pluck(:id)
  end

  def registrant_ids
    @registrant_ids ||= active_registrations.pluck(:registrant_id)
  end

  # Facilitator status for one represented organization, used by the
  # program-status breakdown. Prefers a registrant's own active affiliation to
  # the org as the reference point, falling back to the org's earliest
  # facilitator affiliation, and treating an org with no facilitator history as
  # new.
  def program_status_for(organization)
    reference = registrant_affiliations_by_org[organization.id]
      &.select(&:facilitator?)
      &.min_by { |affiliation| affiliation.start_date || Date.current }
    return organization.facilitator_status(reference) if reference

    # The registrant has no facilitator affiliation to this org yet (admins create
    # those manually after the fact). Classify the org as of today rather than
    # treating it as new by default, so an org that already has an active
    # facilitator reads as :ongoing and a lapsed one as :reinstated.
    organization.facilitator_status_on(Date.current)
  end

  # This event's active registrants' active affiliations, grouped by organization
  # id — the reference points for the program-status breakdown.
  def registrant_affiliations_by_org
    @registrant_affiliations_by_org ||= Affiliation.active_or_pending
      .where(person_id: registrant_ids)
      .includes(:organization)
      .group_by(&:organization_id)
  end

  def scholarship_applicant_ids
    @scholarship_applicant_ids ||= active_registrations.where(scholarship_requested: true).pluck(:registrant_id)
  end

  # Registrant (Person) ids behind active registrations that opted into a
  # shout-out — the candidates for the recipients page shout-out block.
  def shoutout_registrant_ids
    @shoutout_registrant_ids ||= active_registrations.where(shoutout: true).pluck(:registrant_id)
  end

  # People who opted into a shout-out, sorted by display name, with affiliations,
  # organizations, sectors, and age-range categories preloaded for the shout-out
  # block (org link + the primary sector / age-group parenthetical).
  def shoutout_registrants
    @shoutout_registrants ||= Person
      .where(id: shoutout_registrant_ids)
      .includes({ affiliations: :organization }, { sectorable_items: :sector }, { categories: :category_type })
      .sort_by(&:name)
  end

  # The person's primary service area: the sector they marked primary, falling
  # back to their first sector alphabetically. Nil when they have none.
  def primary_sector_name_for(person)
    person.sectorable_items_primary_first.first&.sector&.name
  end

  # The person's age group(s) served, from their AgeRange profile tags, ", "-joined.
  # Nil when they have none.
  def age_group_text_for(person)
    person.categories.select { |category| category.category_type&.name == "AgeRange" }.map(&:name).join(", ").presence
  end

  # Ids of every form submission the applicants made for this event's forms —
  # the registration form and/or the scholarship form.
  def applicant_submission_ids
    @applicant_submission_ids ||= FormSubmission
      .where(person_id: scholarship_applicant_ids, form_id: event.forms.ids)
      .pluck(:id)
  end

  # Non-blank answers for the given field identifiers across the applicants'
  # event submissions, grouped by Person id, with fields and submissions
  # preloaded.
  def applicant_answers_for(identifiers)
    FormAnswer
      .joins(:form_field)
      .where(form_submission_id: applicant_submission_ids)
      .where(form_fields: { field_identifier: identifiers })
      .where.not(submitted_answer: [ nil, "" ])
      .includes(:form_field, :form_submission)
      .group_by { |answer| answer.form_submission.person_id }
  end

  # Keep one answer per question, ordered to match the scholarship section, so a
  # recipient who answered the same question on two submissions shows it once.
  def dedupe_answers(answers)
    answers
      .group_by { |answer| answer.form_field&.field_identifier }
      .values
      .map(&:first)
      .sort_by { |answer| SCHOLARSHIP_ANSWER_IDENTIFIERS.index(answer.form_field&.field_identifier) || SCHOLARSHIP_ANSWER_IDENTIFIERS.length }
  end

  def registration_allocations
    Allocation.where(allocatable_type: "EventRegistration", allocatable_id: active_registration_ids)
  end

  def allocated_by_registration
    @allocated_by_registration ||= registration_allocations.group(:allocatable_id).sum(:amount)
  end

  # Payments tied to this event's bulk payment form submissions. Scoped by the
  # submission's own event_id (matching the bulk payments page) rather than the
  # shared form's event_forms, so a form reused across events doesn't pull in
  # other events' submissions.
  def bulk_payments
    @bulk_payments ||= Payment.where(
      form_submission_id: event.form_submissions.where(role: "bulk_payment").select(:id)
    )
  end

  def scholarships
    @scholarships ||= Scholarship
      .joins(:allocation)
      .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: active_registration_ids })
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
      affiliated_ids = Affiliation.active_or_pending
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

  # CategorizableItem rows tying registrants to StoryPopulation (life-experience)
  # categories — the source for the life-experience breakdown.
  def life_experience_items
    CategorizableItem
      .joins(category: :category_type)
      .where(categorizable_type: "Person", categorizable_id: registrant_ids)
      .where(category_types: { name: "StoryPopulation" })
  end

  def registrant_life_experience_ids
    @registrant_life_experience_ids ||= life_experience_items.distinct.pluck(:category_id)
  end

  # CategorizableItem rows tying registrants to WorkshopEnvironment (workshop
  # settings) categories — the source for the settings breakdown.
  def settings_items
    CategorizableItem
      .joins(category: :category_type)
      .where(categorizable_type: "Person", categorizable_id: registrant_ids)
      .where(category_types: { name: "WorkshopEnvironment" })
  end

  def registrant_settings_ids
    @registrant_settings_ids ||= settings_items.distinct.pluck(:category_id)
  end

  # [ person_id, age_group_category_id ] for every AgeRange selection in active
  # registrants' "primary_age_group" registration answers. The answer text is a
  # ", "-joined list of category ids (the checkbox values); non-numeric tokens
  # (legacy free text) are ignored. Deduped per [ person, category ].
  def age_group_answer_rows
    @age_group_answer_rows ||= compute_age_group_answer_rows
  end

  def compute_age_group_answer_rows
    field = registration_form_field("primary_age_group")
    return [] unless field

    FormAnswer
      .where(form_field_id: field.id)
      .joins(:form_submission)
      .where(form_submissions: { person_id: registrant_ids })
      .pluck(Arel.sql("form_submissions.person_id"), :submitted_answer)
      .flat_map do |person_id, submitted_answer|
        submitted_answer.to_s.split(",").map(&:strip)
          .select { |token| token.match?(/\A\d+\z/) }
          .map { |token| [ person_id, token.to_i ] }
      end
      .uniq
  end

  # Distinct sector ids registrants named as their primary sector, limited
  # to sectors actually represented among registrants.
  def primary_sector_ids
    @primary_sector_ids ||= primary_sector_rows.map(&:last).uniq & registrant_sector_ids
  end

  # Distinct sectors a registrant has as a tag without having named that sector as
  # their own primary sector. Overlaps primary_sector_ids when a sector is
  # primary for one registrant and additional for another.
  def additional_sector_ids
    @additional_sector_ids ||= begin
      primary_pairs = primary_sector_rows.to_set
      registrant_sector_pairs.reject { |pair| primary_pairs.include?(pair) }.map(&:last).uniq
    end
  end

  # [ person_id, sector_id ] pairs for every sector tag on the registrants.
  def registrant_sector_pairs
    @registrant_sector_pairs ||= SectorableItem
      .where(sectorable_type: "Person", sectorable_id: registrant_ids)
      .distinct
      .pluck(:sectorable_id, :sector_id)
  end

  # [ person_id, sector_id ] pairs from registrants' primary sector answers.
  # Read from the single-select dropdown (PRIMARY_SECTOR_FIELD_IDENTIFIERS); the
  # multi-select checkbox field collects the Additional sectors.
  def primary_sector_rows
    field = registration_form_field(FormField::PRIMARY_SECTOR_FIELD_IDENTIFIERS)
    return [] unless field

    FormAnswer
      .where(form_field_id: field.id)
      .joins(:form_submission)
      .where(form_submissions: { person_id: registrant_ids })
      .pluck(Arel.sql("form_submissions.person_id"), :submitted_answer)
      .flat_map do |person_id, submitted_answer|
        submitted_answer.to_s.split(",").map(&:strip)
          .select { |token| token.match?(/\A\d+\z/) }
          .map { |token| [ person_id, token.to_i ] }
      end
      .uniq
  end

  # The registration form field with the given identifier, if the event's
  # registration form asks it. Memoized per identifier.
  def registration_form_field(identifier)
    @registration_form_fields ||= {}
    return @registration_form_fields[identifier] if @registration_form_fields.key?(identifier)
    @registration_form_fields[identifier] = event.registration_form&.form_fields&.find_by(field_identifier: identifier)
  end

  # State abbreviation for a US address, otherwise the country's ISO 3-letter
  # code; falls back to the (uppercased) state when the country can't be resolved.
  def location_label(state, country)
    return state.to_s.strip.upcase.presence if domestic_country?(country)
    country_alpha3(country) || state.to_s.strip.upcase.presence
  end

  # Treat a blank country as domestic (US addresses often omit it).
  def domestic_country?(country)
    return true if country.blank?
    resolved_country(country)&.alpha3 == "USA"
  end

  def country_alpha3(country)
    return if country.blank?
    resolved_country(country)&.alpha3 || country.gsub(/[^A-Za-z]/, "").first(3).upcase.presence
  end

  def resolved_country(country)
    @resolved_countries ||= {}
    return @resolved_countries[country] if @resolved_countries.key?(country)
    @resolved_countries[country] = ISO3166::Country.find_country_by_any_name(country)
  end
end
