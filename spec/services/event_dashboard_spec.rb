require "rails_helper"

RSpec.describe EventDashboard do
  subject(:dashboard) { described_class.new(event) }

  context "with a populated paid event" do
    let(:event) { create(:event, cost_cents: 10_000) }

    # Two active registrants and one cancelled (which should be ignored everywhere).
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }
    let(:cancelled_person) { create(:person) }

    let(:org_a) { create(:organization, name: "Alpha Org") }
    let(:org_b) { create(:organization, name: "Beta Org") }
    let(:org_c) { create(:organization, name: "Gamma Org") }
    let(:org_excluded) { create(:organization, name: "Excluded Org") }

    let(:sector1) { create(:sector, name: "Domestic Violence") }
    let(:sector2) { create(:sector, name: "Mental Health") }
    let(:sector_excluded) { create(:sector, name: "Veterans & Military") }

    let(:story_population) { create(:category_type, name: "StoryPopulation") }
    let(:experience1) { create(:category, name: "Veterans", category_type: story_population) }
    let(:experience2) { create(:category, name: "Survivors", category_type: story_population) }
    let(:experience_excluded) { create(:category, name: "Elders", category_type: story_population) }

    let(:workshop_environment) { create(:category_type, name: "WorkshopEnvironment") }
    let(:setting1) { create(:category, name: "Clinical", category_type: workshop_environment) }
    let(:setting2) { create(:category, name: "Educational", category_type: workshop_environment) }
    let(:setting_excluded) { create(:category, name: "Virtually", category_type: workshop_environment) }

    let(:age_range) { create(:category_type, name: "AgeRange") }
    let(:age_group1) { create(:category, name: "Adults", category_type: age_range) }
    let(:age_group2) { create(:category, name: "Teens", category_type: age_range) }
    let(:age_group_excluded) { create(:category, name: "Children", category_type: age_range) }

    # Age group is read from the registration form's "primary_age_group" answers
    # (", "-joined AgeRange category ids), not from profile tags.
    let(:registration_form) { create(:form, name: "Registration") }
    let(:age_group_field) do
      create(:form_field, form: registration_form, field_identifier: "primary_age_group",
                          name: "Primary Age Group(s) Served", answer_type: :multi_select_checkbox)
    end

    let!(:reg1) do
      # Affiliation exists before registration so it is captured in the snapshot.
      create(:affiliation, person: person1, organization: org_a)
      create(:event_registration, event: event, registrant: person1, status: "registered")
    end

    let!(:reg2) do
      create(:affiliation, person: person2, organization: org_c)
      create(:event_registration, event: event, registrant: person2, status: "registered")
    end

    before do
      # Affiliation added after registration: present via active affiliations, not the snapshot.
      create(:affiliation, person: person1, organization: org_b)

      # Cancelled registration — its org/sector/state/money must be ignored.
      create(:affiliation, person: cancelled_person, organization: org_excluded)
      cancelled_reg = create(:event_registration, event: event, registrant: cancelled_person, status: "cancelled")
      create(:allocation, source: create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000),
                          allocatable: cancelled_reg, amount: 5_000)

      # Money: reg1 fully covered (payment + scholarship), reg2 partly paid.
      create(:allocation, source: create(:payment, amount_cents: 6_000, amount_cents_remaining: 6_000),
                          allocatable: reg1, amount: 6_000)
      scholarship = create(:scholarship, recipient: person1, amount_cents: 4_000, tasks_completed: true)
      create(:allocation, source: scholarship, allocatable: reg1, amount: 4_000)

      create(:allocation, source: create(:payment, amount_cents: 3_000, amount_cents_remaining: 3_000),
                          allocatable: reg2, amount: 3_000)

      # Sectors on registrants (sector1 shared, sector2 unique, excluded one belongs to cancelled person).
      create(:sectorable_item, sector: sector1, sectorable: person1)
      create(:sectorable_item, sector: sector1, sectorable: person2)
      create(:sectorable_item, sector: sector2, sectorable: person2)
      create(:sectorable_item, sector: sector_excluded, sectorable: cancelled_person)

      # Life experiences (StoryPopulation categories) on registrants; the excluded
      # one belongs to the cancelled person.
      create(:categorizable_item, category: experience1, categorizable: person1)
      create(:categorizable_item, category: experience1, categorizable: person2)
      create(:categorizable_item, category: experience2, categorizable: person2)
      create(:categorizable_item, category: experience_excluded, categorizable: cancelled_person)

      # Workshop settings (WorkshopEnvironment categories) on registrants; the
      # excluded one belongs to the cancelled person.
      create(:categorizable_item, category: setting1, categorizable: person1)
      create(:categorizable_item, category: setting1, categorizable: person2)
      create(:categorizable_item, category: setting2, categorizable: person2)
      create(:categorizable_item, category: setting_excluded, categorizable: cancelled_person)

      # Primary age group(s) served, captured as "primary_age_group" answers on
      # each registrant's registration submission (", "-joined AgeRange ids).
      # person1 → Adults; person2 → Adults + Teens; cancelled → Children (ignored).
      create(:event_form, event: event, form: registration_form, role: "registration")
      create(:form_answer, form_field: age_group_field, submitted_answer: age_group1.id.to_s,
                           form_submission: create(:form_submission, person: person1, form: registration_form))
      create(:form_answer, form_field: age_group_field, submitted_answer: "#{age_group1.id}, #{age_group2.id}",
                           form_submission: create(:form_submission, person: person2, form: registration_form))
      create(:form_answer, form_field: age_group_field, submitted_answer: age_group_excluded.id.to_s,
                           form_submission: create(:form_submission, person: cancelled_person, form: registration_form))

      # States from active registrant addresses; inactive address excluded.
      create(:address, addressable: person1, state: "CA", county: "Los Angeles")
      create(:address, addressable: person2, state: "NY", county: "Kings")
      create(:address, addressable: person2, state: "TX", county: "Travis", inactive: true)
      create(:address, addressable: cancelled_person, state: "FL", county: "Miami-Dade")
    end

    it "counts only active registrants" do
      expect(dashboard.registrant_count).to eq(2)
    end

    it "counts inactive (cancelled / no-show) registrations" do
      expect(dashboard.inactive_registration_count).to eq(1)
    end

    it "returns the registrant ids behind the inactive registrations" do
      expect(dashboard.inactive_registrant_ids).to contain_exactly(cancelled_person.id)
    end

    it "returns only active registrants as Person records" do
      expect(dashboard.registrants).to contain_exactly(person1, person2)
    end

    describe "money" do
      it "sums received payments across active registrations" do
        expect(dashboard.received_cents).to eq(9_000)
      end

      it "reports outstanding as the remaining cost after payments and scholarships" do
        expect(dashboard.outstanding_cents).to eq(7_000)
      end

      it "reports total as full-price value of active registrations" do
        expect(dashboard.total_cents).to eq(20_000)
      end

      it "reports registration subtotal as received plus outstanding" do
        expect(dashboard.registration_subtotal_cents).to eq(16_000)
      end

      it "reports grand total as registration subtotal plus completed scholarships plus cont ed plus unallocated bulk payments" do
        expect(dashboard.grand_total_cents).to eq(20_000)
        expect(dashboard.grand_total_cents).to eq(
          dashboard.registration_subtotal_cents + dashboard.scholarship_total_cents +
            dashboard.cont_ed_total_cents + dashboard.unallocated_bulk_payment_cents
        )
      end

      it "reports no unallocated bulk payments without a bulk payment form" do
        expect(dashboard.unallocated_bulk_payment_cents).to eq(0)
      end

      it "is not free when the event has a cost" do
        expect(dashboard.free?).to be(false)
      end

      it "counts registrants paid in full" do
        expect(dashboard.paid_count).to eq(1)
      end

      it "counts registrants not paid in full" do
        expect(dashboard.unpaid_count).to eq(1)
      end
    end

    describe "scholarships" do
      it "sums scholarship dollars for active registrations" do
        expect(dashboard.scholarship_total_cents).to eq(4_000)
      end

      it "counts unique scholarship recipients" do
        expect(dashboard.scholarship_recipient_count).to eq(1)
      end
    end

    describe "organizations" do
      it "combines snapshot orgs and active affiliation orgs, deduped" do
        expect(dashboard.organizations).to contain_exactly(org_a, org_b, org_c)
      end

      it "counts unique organizations" do
        expect(dashboard.organization_count).to eq(3)
      end

      it "buckets each program as new when it is the registrant's first facilitator affiliation" do
        expect(dashboard.program_status_counts).to eq(new: 3, ongoing: 0, reinstated: 0)
      end

      it "totals the program-status breakdown to the organization count" do
        expect(dashboard.program_status_counts.values.sum).to eq(dashboard.organization_count)
      end

      it "counts distinct registrants per organization" do
        expect(dashboard.organization_counts).to eq(org_a.id => 1, org_b.id => 1, org_c.id => 1)
      end

      it "returns the registrant ids tied to an organization" do
        expect(dashboard.organization_registrant_ids).to contain_exactly(person1.id, person2.id)
      end

      it "maps each organization to its registrant ids" do
        map = dashboard.organization_registrant_ids_by_org
        expect(map[org_a.id].to_a).to contain_exactly(person1.id)
        expect(map[org_b.id].to_a).to contain_exactly(person1.id)
        expect(map[org_c.id].to_a).to contain_exactly(person2.id)
      end

      it "maps each registrant id to its organization names (for tooltips)" do
        map = dashboard.organization_names_by_registrant
        expect(map[person1.id]).to contain_exactly("Alpha Org", "Beta Org")
        expect(map[person2.id]).to contain_exactly("Gamma Org")
      end
    end

    describe "sectors" do
      it "returns unique sectors across active registrants" do
        expect(dashboard.sectors).to contain_exactly(sector1, sector2)
      end

      it "counts distinct registrants per sector" do
        expect(dashboard.sector_counts).to eq(sector1.id => 2, sector2.id => 1)
      end

      it "returns the registrant ids that belong to a sector" do
        expect(dashboard.sector_registrant_ids).to contain_exactly(person1.id, person2.id)
      end
    end

    describe "sector primary/additional split (overlapping)" do
      before do
        # person1 names sector1 as primary; person2 names sector2 as primary via the
        # single-select dropdown. Both also carry sector1 as a tag, so sector1 is
        # primary for person1 AND an additional sector for person2 — the counts
        # overlap (don't partition).
        service_field = create(:form_field, form: registration_form, field_identifier: "primary_service_area_single",
                                            answer_type: :single_select_dropdown)
        create(:form_answer, form_field: service_field, submitted_answer: sector1.id.to_s,
                             form_submission: FormSubmission.find_by!(person: person1, form: registration_form))
        create(:form_answer, form_field: service_field, submitted_answer: sector2.id.to_s,
                             form_submission: FormSubmission.find_by!(person: person2, form: registration_form))
      end

      it "counts distinct sectors named as a primary service area" do
        expect(dashboard.primary_sector_count).to eq(2)
      end

      it "counts sectors carried as a non-primary tag, overlapping the primary count" do
        # sector1 is a tag for person2, who named sector2 (not sector1) as primary.
        expect(dashboard.additional_sector_count).to eq(1)
      end

      it "counts distinct registrants per primary sector, from the dropdown only" do
        expect(dashboard.primary_sector_counts).to eq(sector1.id => 1, sector2.id => 1)
      end

      it "exposes only the dropdown-named sectors as primary (not every tag)" do
        expect(dashboard.primary_sectors).to contain_exactly(sector1, sector2)
      end

      it "maps each primary sector to the registrants who named it, for drill-in" do
        map = dashboard.primary_sector_registrant_ids_by_sector
        expect(map[sector1.id]).to contain_exactly(person1.id)
        expect(map[sector2.id]).to contain_exactly(person2.id)
      end
    end

    describe "life experiences" do
      it "returns unique life-experience categories across active registrants" do
        expect(dashboard.life_experiences).to contain_exactly(experience1, experience2)
      end

      it "counts distinct registrants per life experience" do
        expect(dashboard.life_experience_counts).to eq(experience1.id => 2, experience2.id => 1)
      end

      it "returns the registrant ids tagged with a life experience" do
        expect(dashboard.life_experience_registrant_ids).to contain_exactly(person1.id, person2.id)
      end

      it "maps each life experience to its registrant ids" do
        map = dashboard.life_experience_registrant_ids_by_category
        expect(map[experience1.id]).to contain_exactly(person1.id, person2.id)
        expect(map[experience2.id]).to contain_exactly(person2.id)
      end
    end

    describe "settings" do
      it "returns unique setting categories across active registrants" do
        expect(dashboard.settings).to contain_exactly(setting1, setting2)
      end

      it "counts distinct registrants per setting" do
        expect(dashboard.settings_counts).to eq(setting1.id => 2, setting2.id => 1)
      end

      it "returns the registrant ids tagged with a setting" do
        expect(dashboard.settings_registrant_ids).to contain_exactly(person1.id, person2.id)
      end

      it "maps each setting to its registrant ids" do
        map = dashboard.settings_registrant_ids_by_category
        expect(map[setting1.id]).to contain_exactly(person1.id, person2.id)
        expect(map[setting2.id]).to contain_exactly(person2.id)
      end
    end

    describe "age groups (from registration responses)" do
      it "returns unique age-group categories from registrants' registration answers" do
        expect(dashboard.age_groups).to contain_exactly(age_group1, age_group2)
      end

      it "counts distinct registrants per age group" do
        expect(dashboard.age_group_counts).to eq(age_group1.id => 2, age_group2.id => 1)
      end

      it "returns the registrant ids who answered the age group question" do
        expect(dashboard.age_group_registrant_ids).to contain_exactly(person1.id, person2.id)
      end

      it "maps each age group to its registrant ids" do
        map = dashboard.age_group_registrant_ids_by_category
        expect(map[age_group1.id]).to contain_exactly(person1.id, person2.id)
        expect(map[age_group2.id]).to contain_exactly(person2.id)
      end
    end

    describe "states" do
      it "returns unique states from active registrants' active addresses" do
        expect(dashboard.states).to eq(%w[CA NY])
      end

      it "counts distinct registrants per state" do
        expect(dashboard.state_counts).to eq("CA" => 1, "NY" => 1)
      end

      it "returns the registrant ids that have a state on file" do
        expect(dashboard.state_registrant_ids).to contain_exactly(person1.id, person2.id)
      end
    end

    describe "counties" do
      it "returns unique [ state, county ] pairs from active registrants' active addresses" do
        expect(dashboard.counties).to eq([ [ "CA", "Los Angeles" ], [ "NY", "Kings" ] ])
      end
    end

    describe "countries" do
      it "returns the registrant ids that have a country on file, excluding inactive and cancelled" do
        expect(dashboard.country_registrant_ids).to contain_exactly(person1.id, person2.id)
      end

      it "counts only active registrants' active addresses" do
        expect(dashboard.country_counts.values.sum).to eq(2)
      end

      it "maps each country to its registrant ids" do
        expect(dashboard.country_registrant_ids_by_country.values.flatten).to contain_exactly(person1.id, person2.id)
      end
    end

    describe "school districts" do
      before do
        person1.addresses.first.update!(district: "Los Angeles Unified")
        person2.addresses.where(inactive: false).first.update!(district: "Garden Grove Unified")
        cancelled_person.addresses.first.update!(district: "Excluded Unified")
      end

      it "lists distinct school districts from active registrants' addresses" do
        expect(dashboard.school_districts).to eq([ "Garden Grove Unified", "Los Angeles Unified" ])
      end

      it "counts distinct registrants per district" do
        expect(dashboard.school_district_counts).to eq("Los Angeles Unified" => 1, "Garden Grove Unified" => 1)
      end

      it "returns the registrant ids behind each district, excluding cancelled" do
        expect(dashboard.school_district_registrant_ids).to contain_exactly(person1.id, person2.id)
      end
    end

    describe "location labels" do
      it "labels a US address by its state abbreviation" do
        domestic = create(:person)
        create(:event_registration, event: event, registrant: domestic, status: "registered")
        create(:address, addressable: domestic, state: "tx", country: "United States")

        expect(dashboard.location_label_by_registrant[domestic.id]).to eq("TX")
      end

      it "labels an international address by its ISO 3-letter country code" do
        intl = create(:person)
        create(:event_registration, event: event, registrant: intl, status: "registered")
        create(:address, addressable: intl, state: "ON", country: "Canada")

        expect(dashboard.location_label_by_registrant[intl.id]).to eq("CAN")
      end
    end
  end

  describe "scholarship applicants" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registration_form) { create(:form, name: "Registration") }
    let(:scholarship_form) { create(:form, :scholarship) }
    # impact_description belongs to the scholarship section wherever it is asked.
    let!(:impact_field) do
      create(:form_field, form: scholarship_form, name: "How will this impact the people you serve?",
                          field_identifier: "impact_description")
    end

    # "Most" recipient: registered with scholarship requested, so the scholarship
    # answers ride along on the registration submission.
    let(:embedded_applicant) { create(:person, first_name: "Tara", last_name: "Gallagher") }
    # "Few" recipient: a separate scholarship submission alongside registration.
    let(:separate_applicant) { create(:person, first_name: "Lucero", last_name: "Sosa") }
    let(:non_applicant) { create(:person, first_name: "Pat", last_name: "Plain") }

    before do
      create(:event_form, :registration, event: event, form: registration_form)
      create(:event_form, :scholarship, event: event, form: scholarship_form)

      create(:event_registration, event: event, registrant: embedded_applicant, status: "registered", scholarship_requested: true)
      create(:event_registration, event: event, registrant: separate_applicant, status: "registered", scholarship_requested: true)
      create(:event_registration, event: event, registrant: non_applicant, status: "registered", scholarship_requested: false)

      # Embedded: scholarship answer captured on the registration submission.
      reg_submission = create(:form_submission, person: embedded_applicant, form: registration_form)
      create(:form_answer, form_submission: reg_submission, form_field: impact_field, submitted_answer: "To serve survivors.")

      # Separate: scholarship answer on a dedicated scholarship submission.
      sch_submission = create(:form_submission, person: separate_applicant, form: scholarship_form, role: "scholarship")
      create(:form_answer, form_submission: sch_submission, form_field: impact_field, submitted_answer: "To support youth.")
    end

    it "returns only registrants who requested a scholarship, sorted by name" do
      expect(dashboard.scholarship_applicants).to eq([ separate_applicant, embedded_applicant ])
    end

    it "gathers scholarship answers wherever they were captured, keyed by applicant" do
      answers = dashboard.scholarship_answers_by_applicant

      expect(answers[embedded_applicant.id].map(&:submitted_answer)).to eq([ "To serve survivors." ])
      expect(answers[separate_applicant.id].map(&:submitted_answer)).to eq([ "To support youth." ])
      expect(answers).not_to have_key(non_applicant.id)
    end

    it "de-duplicates a question answered on both the registration and scholarship submissions" do
      sch_submission = create(:form_submission, person: embedded_applicant, form: scholarship_form, role: "scholarship")
      create(:form_answer, form_submission: sch_submission, form_field: impact_field, submitted_answer: "Duplicate answer.")

      expect(dashboard.scholarship_answers_by_applicant[embedded_applicant.id].size).to eq(1)
    end

    it "gathers header (service area / age group) answers keyed by applicant and identifier" do
      service_field = create(:form_field, form: registration_form, name: "Primary service area", field_identifier: "primary_service_area")
      reg_submission = FormSubmission.find_by(person: embedded_applicant, form: registration_form)
      create(:form_answer, form_submission: reg_submission, form_field: service_field, submitted_answer: "5")

      header = dashboard.header_answers_by_applicant

      expect(header[embedded_applicant.id]["primary_service_area"].submitted_answer).to eq("5")
      expect(header).not_to have_key(non_applicant.id)
    end

    describe "shout outs" do
      let(:org_with_bio) { create(:organization, name: "New Economics for Women", description: "Fights for economic justice for women.") }
      let(:org_without_bio) { create(:organization, name: "Quiet Org", description: "") }

      it "pairs each recipient who has an affiliated org with a bio to that org and its description" do
        create(:affiliation, person: embedded_applicant, organization: org_with_bio)

        shoutout = dashboard.scholarship_shoutouts.find { |s| s.recipient == embedded_applicant }
        expect(shoutout.organization).to eq(org_with_bio)
        expect(shoutout.bio).to eq("Fights for economic justice for women.")
      end

      it "omits recipients with no affiliated organization" do
        expect(dashboard.scholarship_shoutouts.map(&:recipient)).not_to include(separate_applicant)
      end

      it "omits recipients whose organization has no bio on file" do
        create(:affiliation, person: separate_applicant, organization: org_without_bio)

        expect(dashboard.scholarship_shoutouts.map(&:recipient)).not_to include(separate_applicant)
      end
    end
  end

  describe "money breakdown registrant lists" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:paid_person) { create(:person) }
    let(:unpaid_person) { create(:person) }
    let(:completed_person) { create(:person) }
    let(:pending_person) { create(:person) }

    let!(:paid_reg) { create(:event_registration, event: event, registrant: paid_person, status: "registered") }
    let!(:unpaid_reg) { create(:event_registration, event: event, registrant: unpaid_person, status: "registered") }
    let!(:completed_reg) { create(:event_registration, event: event, registrant: completed_person, status: "registered") }
    let!(:pending_reg) { create(:event_registration, event: event, registrant: pending_person, status: "registered") }

    before do
      create(:allocation, source: create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000),
                          allocatable: paid_reg, amount: 10_000)
      create(:allocation, source: create(:payment, amount_cents: 2_000, amount_cents_remaining: 2_000),
                          allocatable: unpaid_reg, amount: 2_000)
      completed = create(:scholarship, recipient: completed_person, amount_cents: 10_000, tasks_completed: true)
      create(:allocation, source: completed, allocatable: completed_reg, amount: 10_000)
      pending = create(:scholarship, recipient: pending_person, amount_cents: 10_000, tasks_completed: false)
      create(:allocation, source: pending, allocatable: pending_reg, amount: 10_000)
    end

    it "lists registrants paid in full (including scholarship-covered)" do
      expect(dashboard.paid_registrants).to contain_exactly(paid_person, completed_person, pending_person)
    end

    it "lists registrants not paid in full" do
      expect(dashboard.unpaid_registrants).to contain_exactly(unpaid_person)
    end

    it "reports all scholarships as allocated" do
      expect(dashboard.scholarship_total_cents).to eq(20_000)
    end

    it "lists all scholarship recipients" do
      expect(dashboard.scholarship_registrants).to contain_exactly(completed_person, pending_person)
    end

    describe "per-person amounts" do
      it "maps each registrant to their registration paid amount, reconciling with received" do
        amounts = dashboard.registration_paid_by_registrant
        expect(amounts[paid_person.id]).to eq(10_000)
        expect(amounts[unpaid_person.id]).to eq(2_000)
        expect(amounts.values.sum).to eq(dashboard.received_cents)
      end

      it "maps each registrant to their registration due amount, reconciling with outstanding" do
        amounts = dashboard.registration_due_by_registrant
        expect(amounts[unpaid_person.id]).to eq(8_000)
        expect(amounts).not_to have_key(pending_person.id)
        expect(amounts.values.sum).to eq(dashboard.outstanding_cents)
      end

      it "maps each recipient to their scholarship amount" do
        amounts = dashboard.scholarship_amounts_by_recipient
        expect(amounts[completed_person.id]).to eq(10_000)
        expect(amounts[pending_person.id]).to eq(10_000)
        expect(amounts.values.sum).to eq(dashboard.scholarship_total_cents)
      end
    end

    it "reports collected as payments received plus cont ed paid, excluding scholarships" do
      expect(dashboard.collected_cents).to eq(12_000)
    end

    it "reports due as outstanding registration plus cont ed fees" do
      expect(dashboard.due_cents).to eq(8_000)
    end

    it "splits monies made into collected and due" do
      expect(dashboard.collected_cents + dashboard.due_cents).to eq(dashboard.monies_made_cents)
    end

    it "reports monies made as registration fees plus cont ed fees, excluding scholarships" do
      expect(dashboard.monies_made_cents).to eq(20_000)
      expect(dashboard.monies_made_cents).to eq(dashboard.grand_total_cents - dashboard.scholarship_total_cents)
    end
  end

  # Continuing-education fees are stubbed to zero until the feature (and its
  # migration) lands. The dashboard still renders the section, showing $0.
  describe "continuing-education fees (stubbed)" do
    let(:event) { create(:event, cost_cents: 10_000) }

    before do
      create(:event_registration, event: event, registrant: create(:person), status: "registered")
    end

    it "reports zero across totals, splits, and registrant lists" do
      expect(dashboard.cont_ed_total_cents).to eq(0)
      expect(dashboard.cont_ed_paid_cents).to eq(0)
      expect(dashboard.cont_ed_outstanding_cents).to eq(0)
      expect(dashboard.cont_ed_paid_count).to eq(0)
      expect(dashboard.cont_ed_unpaid_count).to eq(0)
      expect(dashboard.cont_ed_paid_registrants).to be_empty
      expect(dashboard.cont_ed_unpaid_registrants).to be_empty
    end

    it "adds nothing to the grand total" do
      expect(dashboard.grand_total_cents).to eq(
        dashboard.scholarship_total_cents + dashboard.received_cents + dashboard.outstanding_cents
      )
    end
  end

  # All scholarships are fully allocated regardless of tasks_completed, so the
  # grand total never exceeds the full-price total.
  context "with a scholarship" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:recipient) { create(:person) }
    let!(:registration) { create(:event_registration, event: event, registrant: recipient, status: "registered") }

    before do
      scholarship = create(:scholarship, recipient: recipient, amount_cents: 10_000, tasks_completed: false)
      create(:allocation, source: scholarship, allocatable: registration, amount: 10_000)
    end

    it "reports the awarded amount on the scholarship card headline" do
      expect(dashboard.scholarship_total_cents).to eq(10_000)
    end

    it "does not let the grand total exceed the full-price total" do
      expect(dashboard.grand_total_cents).to eq(dashboard.total_cents)
      expect(dashboard.grand_total_cents).to eq(10_000)
    end
  end

  context "with a free event" do
    let(:event) { create(:event, cost_cents: 0) }

    it "is free and has no total or outstanding cost" do
      expect(dashboard.free?).to be(true)
      expect(dashboard.total_cents).to eq(0)
      expect(dashboard.outstanding_cents).to eq(0)
    end
  end

  context "with no registrations" do
    let(:event) { create(:event, cost_cents: 10_000) }

    it "reports zeros and empty collections" do
      expect(dashboard.registrant_count).to eq(0)
      expect(dashboard.registrants).to be_empty
      expect(dashboard.total_cents).to eq(0)
      expect(dashboard.received_cents).to eq(0)
      expect(dashboard.outstanding_cents).to eq(0)
      expect(dashboard.scholarship_total_cents).to eq(0)
      expect(dashboard.organizations).to be_empty
      expect(dashboard.sectors).to be_empty
      expect(dashboard.states).to be_empty
    end

    it "reports an empty program-status breakdown" do
      expect(dashboard.program_status_counts).to eq(new: 0, ongoing: 0, reinstated: 0)
    end
  end

  context "program-status breakdown across registrants' programs" do
    let(:event) { create(:event) }

    let(:new_org) { create(:organization, name: "New Program") }
    let(:ongoing_org) { create(:organization, name: "Ongoing Program") }
    let(:reinstated_org) { create(:organization, name: "Reinstated Program") }

    let(:new_facilitator) { create(:person) }
    let(:ongoing_facilitator) { create(:person) }
    let(:reinstated_facilitator) { create(:person) }
    let(:cancelled_facilitator) { create(:person) }

    before do
      # New program: the registrant's affiliation is the org's first facilitator.
      create(:affiliation, organization: new_org, person: new_facilitator,
             title: "Facilitator", start_date: Date.new(2026, 1, 1))

      # Ongoing program: a facilitator was already active before this registrant.
      create(:affiliation, organization: ongoing_org,
             title: "Facilitator", start_date: Date.new(2023, 1, 1), end_date: nil)
      create(:affiliation, organization: ongoing_org, person: ongoing_facilitator,
             title: "Facilitator", start_date: Date.new(2026, 1, 1))

      # Reinstated program: a prior facilitator ended before this registrant's.
      create(:affiliation, organization: reinstated_org,
             title: "Facilitator", start_date: Date.new(2020, 1, 1), end_date: Date.new(2021, 1, 1))
      create(:affiliation, organization: reinstated_org, person: reinstated_facilitator,
             title: "Facilitator", start_date: Date.new(2026, 1, 1))

      # Cancelled registrant's program must be ignored.
      create(:affiliation, organization: new_org, person: cancelled_facilitator,
             title: "Facilitator", start_date: Date.new(2026, 2, 1))

      create(:event_registration, event: event, registrant: new_facilitator, status: "registered")
      create(:event_registration, event: event, registrant: ongoing_facilitator, status: "registered")
      create(:event_registration, event: event, registrant: reinstated_facilitator, status: "registered")
      create(:event_registration, event: event, registrant: cancelled_facilitator, status: "cancelled")
    end

    it "buckets each active registrant's program by its facilitator status" do
      expect(dashboard.program_status_counts).to eq(new: 1, ongoing: 1, reinstated: 1)
    end

    it "maps each registrant to their organization's program status" do
      statuses = dashboard.program_statuses_by_registrant

      expect(statuses[new_facilitator.id]).to eq([ :new ])
      expect(statuses[ongoing_facilitator.id]).to eq([ :ongoing ])
      expect(statuses[reinstated_facilitator.id]).to eq([ :reinstated ])
      expect(statuses).not_to have_key(cancelled_facilitator.id)
    end
  end

  context "program-status breakdown for non-facilitator affiliations" do
    let(:event) { create(:event) }
    let(:org) { create(:organization, name: "Day Job Agency") }
    let(:person) { create(:person) }

    before do
      # The registrant's only affiliation is a job title, not a facilitator role —
      # the kind the recipients page surfaces. The program still belongs in the
      # breakdown so the buckets total the organization count.
      create(:affiliation, organization: org, person: person, title: "Outreach Specialist", start_date: 1.year.ago)
      create(:event_registration, event: event, registrant: person, status: "registered")
    end

    it "counts the organization as a new program even without a facilitator affiliation" do
      expect(dashboard.program_status_counts).to eq(new: 1, ongoing: 0, reinstated: 0)
    end

    it "keeps the breakdown total equal to the organization count" do
      expect(dashboard.program_status_counts.values.sum).to eq(dashboard.organization_count)
    end
  end

  describe "unallocated bulk payments" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:bulk_form) { create(:form) }
    let!(:event_form) { create(:event_form, event: event, form: bulk_form, role: "bulk_payment") }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: bulk_form, role: "bulk_payment") }

    it "sums the unallocated remainder across the event's bulk payments" do
      create(:payment, person: payer, form_submission: submission,
             amount_cents: 10_000, amount_cents_remaining: 3_000)
      create(:payment, person: payer, form_submission: submission,
             amount_cents: 5_000, amount_cents_remaining: 5_000)

      expect(dashboard.unallocated_bulk_payment_cents).to eq(8_000)
    end

    it "adds the unallocated remainder to the grand total" do
      create(:payment, person: payer, form_submission: submission,
             amount_cents: 10_000, amount_cents_remaining: 4_000)

      expect(dashboard.grand_total_cents).to eq(
        dashboard.registration_subtotal_cents + dashboard.scholarship_total_cents +
          dashboard.cont_ed_total_cents + 4_000
      )
    end

    it "ignores payments from other events' bulk forms" do
      other_event = create(:event, cost_cents: 10_000)
      other_form = create(:form)
      create(:event_form, event: other_event, form: other_form, role: "bulk_payment")
      other_submission = create(:form_submission, person: payer, form: other_form, role: "bulk_payment")
      create(:payment, person: payer, form_submission: other_submission,
             amount_cents: 9_000, amount_cents_remaining: 9_000)

      expect(dashboard.unallocated_bulk_payment_cents).to eq(0)
    end
  end
end
