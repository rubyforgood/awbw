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
    let(:additional_age_group_field) do
      create(:form_field, form: registration_form, field_identifier: "additional_age_group",
                          name: "Additional Age Group(s) Served", answer_type: :multi_select_checkbox)
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

      # Additional age group(s) served, captured as "additional_age_group" answers.
      # person1 → Adults + Teens (Adults dupes the primary answer, so it dedupes);
      # cancelled → Adults (ignored). This makes "All age groups" (primary +
      # additional) differ from the primary-only breakdown.
      create(:form_answer, form_field: additional_age_group_field,
                           submitted_answer: "#{age_group1.id}, #{age_group2.id}",
                           form_submission: create(:form_submission, person: person1, form: registration_form))
      create(:form_answer, form_field: additional_age_group_field, submitted_answer: age_group1.id.to_s,
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

    describe "other sector responses" do
      before do
        # Free-text "Other" sectors registrants typed (kept as OtherResponse, never
        # real tags). person1 and person2 both typed "Hospice" (different casing →
        # one bucket); person2 also typed "Doula". A dismissed one and the cancelled
        # registrant's response must be ignored.
        create(:other_response, owner: person1, text: "Hospice")
        create(:other_response, :kept, owner: person2, text: "hospice")
        create(:other_response, owner: person2, text: "Doula")
        create(:other_response, :dismissed, owner: person1, text: "Retired")
        create(:other_response, owner: cancelled_person, text: "Hospice")
      end

      it "counts distinct registrants with a visible other-sector response" do
        expect(dashboard.other_sector_response_count).to eq(2)
      end

      it "returns the registrant ids behind the other-sector responses" do
        expect(dashboard.other_sector_response_registrant_ids).to contain_exactly(person1.id, person2.id)
      end

      it "groups the typed values by normalized text, with per-value registrant counts and ids" do
        rows = dashboard.other_sector_response_rows
        expect(rows.map { |text, count, _ids| [ text, count ] }).to eq([
          [ "Hospice", 2 ],
          [ "Doula", 1 ]
        ])
        expect(rows.first.last).to contain_exactly(person1.id, person2.id)
        expect(rows.last.last).to eq([ person2.id ])
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

    describe "all age groups (primary + additional registration responses)" do
      it "returns unique age-group categories across both age group questions" do
        expect(dashboard.all_age_groups).to contain_exactly(age_group1, age_group2)
      end

      it "counts distinct registrants per age group, deduping across both questions" do
        expect(dashboard.all_age_group_counts).to eq(age_group1.id => 2, age_group2.id => 2)
      end

      it "maps each age group to its registrant ids across both questions" do
        map = dashboard.all_age_group_registrant_ids_by_category
        expect(map[age_group1.id]).to contain_exactly(person1.id, person2.id)
        expect(map[age_group2.id]).to contain_exactly(person1.id, person2.id)
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

    it "maps each active registrant to their registration id" do
      map = dashboard.registration_id_by_registrant

      expect(map[embedded_applicant.id]).to eq(EventRegistration.find_by(event: event, registrant: embedded_applicant).id)
      expect(map[separate_applicant.id]).to eq(EventRegistration.find_by(event: event, registrant: separate_applicant).id)
    end

    describe "#scholarship_applicants_by_funder" do
      it "buckets applicants by their scholarship's grant funder, unfunded last, carrying the funder and its city/state" do
        embedded_reg = event.event_registrations.find_by(registrant: embedded_applicant)
        separate_reg = event.event_registrations.find_by(registrant: separate_applicant)
        funder = create(:organization, name: "Joyful Heart Foundation")
        create(:address, addressable: funder, city: "Los Angeles", state: "CA")
        grant = create(:grant, name: "Healing Arts", funder: funder, amount_cents: 100_000)
        funded = create(:scholarship, recipient: embedded_applicant, grant: grant, amount_cents: 1_000)
        create(:allocation, source: funded, allocatable: embedded_reg, amount: 1_000)
        unfunded = create(:scholarship, recipient: separate_applicant, amount_cents: 1_000)
        create(:allocation, source: unfunded, allocatable: separate_reg, amount: 1_000)

        groups = dashboard.scholarship_applicants_by_funder

        expect(groups.map(&:name)).to eq([ "Joyful Heart Foundation", "Unfunded" ])
        expect(groups.first.people).to eq([ embedded_applicant ])
        expect(groups.first.funder).to eq(funder)
        expect(groups.first.location).to eq("Los Angeles, CA")
        expect(groups.last.people).to eq([ separate_applicant ])
        expect(groups.last.funder).to be_nil
      end

      it "collects applicants with no awarded scholarship under 'No scholarship yet'" do
        groups = dashboard.scholarship_applicants_by_funder

        expect(groups.map(&:name)).to eq([ "No scholarship yet" ])
        expect(groups.first.people).to match_array([ embedded_applicant, separate_applicant ])
      end
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

    it "gathers header (sector / age group) answers keyed by applicant, sector answers under the normalized sector key" do
      # Use a legacy "service area" identifier to confirm it still resolves under
      # the normalized sector key alongside the current "sector" identifiers.
      service_field = create(:form_field, form: registration_form, name: "Primary sector", field_identifier: "primary_service_area")
      reg_submission = FormSubmission.find_by(person: embedded_applicant, form: registration_form)
      create(:form_answer, form_submission: reg_submission, form_field: service_field, submitted_answer: "5")

      header = dashboard.header_answers_by_applicant

      expect(header[embedded_applicant.id][EventDashboard::HEADER_SECTOR_KEY].submitted_answer).to eq("5")
      expect(header).not_to have_key(non_applicant.id)
    end

    describe "shout outs" do
      let(:org) { create(:organization, name: "New Economics for Women") }

      def opt_in(person, text:)
        person.update!(shoutout_text: text)
        EventRegistration.find_by(event: event, registrant: person).update!(shoutout: true)
      end

      it "pairs each opted-in registrant's shout-out text with their affiliated organization" do
        opt_in(embedded_applicant, text: "Grateful to bring art to the survivors we serve.")
        create(:affiliation, person: embedded_applicant, organization: org)

        shoutout = dashboard.shoutouts.find { |s| s.recipient == embedded_applicant }
        expect(shoutout.text).to eq("Grateful to bring art to the survivors we serve.")
        expect(shoutout.organization).to eq(org)
      end

      it "exposes the registrant's primary sector and age group" do
        age_range = create(:category_type, name: "AgeRange")
        embedded_applicant.sectorable_items.create!(sector: create(:sector, name: "Sexual Assault"), is_primary: true)
        create(:categorizable_item, category: create(:category, name: "Teens", category_type: age_range), categorizable: embedded_applicant)
        opt_in(embedded_applicant, text: "Here to help.")

        shoutout = dashboard.shoutouts.find { |s| s.recipient == embedded_applicant }
        expect(shoutout.sector).to eq("Sexual Assault")
        expect(shoutout.age_group).to eq("Teens")
      end

      it "includes an opted-in registrant with no affiliated organization (org is optional)" do
        opt_in(separate_applicant, text: "Art has been my way through.")

        shoutout = dashboard.shoutouts.find { |s| s.recipient == separate_applicant }
        expect(shoutout.text).to eq("Art has been my way through.")
        expect(shoutout.organization).to be_nil
      end

      it "is independent of scholarships — a non-scholarship registrant can opt in" do
        opt_in(non_applicant, text: "Proud to support this work.")

        expect(dashboard.shoutouts.map(&:recipient)).to include(non_applicant)
      end

      it "omits registrants who opted in but left their shout-out text blank" do
        opt_in(embedded_applicant, text: "")

        expect(dashboard.shoutouts.map(&:recipient)).not_to include(embedded_applicant)
      end

      it "omits registrants with shout-out text who did not opt in" do
        separate_applicant.update!(shoutout_text: "I have text but did not opt in.")

        expect(dashboard.shoutouts.map(&:recipient)).not_to include(separate_applicant)
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

  # CE fees are billed per ContinuingEducationRegistration and flow through the
  # generic payment/allocation system. The event is free-registration to isolate
  # CE money (and prove CE still reports on a free event). Cancelled registrants'
  # CE is ignored, like their registration fees.
  describe "continuing-education fees" do
    let(:event) { create(:event, cost_cents: 0) }
    let(:paid_person) { create(:person) }
    let(:partial_person) { create(:person) }
    let(:unpaid_person) { create(:person) }

    let!(:paid_reg) { create(:event_registration, event: event, registrant: paid_person, status: "registered") }
    let!(:partial_reg) { create(:event_registration, event: event, registrant: partial_person, status: "registered") }
    let!(:unpaid_reg) { create(:event_registration, event: event, registrant: unpaid_person, status: "registered") }

    before do
      ce_paid = create(:continuing_education_registration, event_registration: paid_reg, cost_cents: 10_000)
      create(:allocation, source: create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000),
                          allocatable: ce_paid, amount: 10_000)

      ce_partial = create(:continuing_education_registration, event_registration: partial_reg, cost_cents: 8_000)
      create(:allocation, source: create(:payment, amount_cents: 3_000, amount_cents_remaining: 3_000),
                          allocatable: ce_partial, amount: 3_000)

      create(:continuing_education_registration, event_registration: unpaid_reg, cost_cents: 6_000)

      cancelled = create(:event_registration, event: event, registrant: create(:person), status: "cancelled")
      ce_cancelled = create(:continuing_education_registration, event_registration: cancelled, cost_cents: 20_000)
      create(:allocation, source: create(:payment, amount_cents: 20_000, amount_cents_remaining: 20_000),
                          allocatable: ce_cancelled, amount: 20_000)
    end

    it "sums CE cash collected across active CE registrations" do
      expect(dashboard.cont_ed_paid_cents).to eq(13_000)
    end

    it "sums CE cost still owed after allocations" do
      expect(dashboard.cont_ed_outstanding_cents).to eq(11_000)
    end

    it "reports CE total as paid plus outstanding" do
      expect(dashboard.cont_ed_total_cents).to eq(24_000)
    end

    it "counts registrants whose CE is fully paid vs still owing" do
      expect(dashboard.cont_ed_paid_count).to eq(1)
      expect(dashboard.cont_ed_unpaid_count).to eq(2)
    end

    it "lists the registrants behind each CE bucket" do
      expect(dashboard.cont_ed_paid_registrants).to contain_exactly(paid_person)
      expect(dashboard.cont_ed_unpaid_registrants).to contain_exactly(partial_person, unpaid_person)
    end

    it "maps each registrant to their CE paid / due amounts, reconciling with the totals" do
      expect(dashboard.cont_ed_paid_by_registrant[paid_person.id]).to eq(10_000)
      expect(dashboard.cont_ed_paid_by_registrant[partial_person.id]).to eq(3_000)
      expect(dashboard.cont_ed_paid_by_registrant.values.sum).to eq(dashboard.cont_ed_paid_cents)

      expect(dashboard.cont_ed_due_by_registrant[partial_person.id]).to eq(5_000)
      expect(dashboard.cont_ed_due_by_registrant[unpaid_person.id]).to eq(6_000)
      expect(dashboard.cont_ed_due_by_registrant.values.sum).to eq(dashboard.cont_ed_outstanding_cents)
    end

    it "counts distinct registrants with continuing education" do
      expect(dashboard.ce_registrant_count).to eq(3)
    end

    it "adds CE fees to the grand total and cash breakdown" do
      expect(dashboard.grand_total_cents).to eq(
        dashboard.registration_subtotal_cents + dashboard.scholarship_total_cents +
          dashboard.cont_ed_total_cents + dashboard.unallocated_bulk_payment_cents
      )
      expect(dashboard.grand_total_cents).to eq(24_000)
      expect(dashboard.collected_cents).to eq(13_000)
      expect(dashboard.due_cents).to eq(11_000)
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

    it "groups registrant ids by program status, for the breakdown drill-in" do
      ids = dashboard.program_status_registrant_ids

      expect(ids[:new]).to contain_exactly(new_facilitator.id)
      expect(ids[:ongoing]).to contain_exactly(ongoing_facilitator.id)
      expect(ids[:reinstated]).to contain_exactly(reinstated_facilitator.id)
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

  # Admins create facilitator affiliations manually after registration, so a
  # registrant frequently has none yet. The org must still be classified by its
  # own history as of the event rather than defaulting to :new.
  context "program-status when the registrant has no facilitator affiliation yet" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }

    before do
      create(:event_registration_organization, event_registration: registration, organization: org)
    end

    let(:registration) { create(:event_registration, event: event, registrant: person, status: "registered") }

    context "an org that already has an active facilitator" do
      let(:org) { create(:organization, name: "Established Agency") }

      before do
        create(:affiliation, organization: org, title: "Facilitator", start_date: 2.years.ago, end_date: nil)
      end

      it "classifies the org as ongoing, not new" do
        expect(dashboard.program_statuses_by_registrant[person.id]).to eq([ :ongoing ])
      end
    end

    context "an org whose only facilitator affiliation has lapsed" do
      let(:org) { create(:organization, name: "Lapsed Agency") }

      before do
        create(:affiliation, organization: org, title: "Facilitator", start_date: 5.years.ago, end_date: 4.years.ago)
      end

      it "classifies the org as reinstated" do
        expect(dashboard.program_statuses_by_registrant[person.id]).to eq([ :reinstated ])
      end
    end
  end

  context "program-status breakdown for a past event whose affiliations have since ended" do
    # The breakdown must reflect the organizations and statuses as they stood at
    # the time of the event, not as they stand today. This registrant's
    # facilitator affiliation was active during the event but has since ended;
    # revisiting the dashboard must still count and classify the program the way
    # it was at the event, rather than dropping it because the affiliation is no
    # longer active right now.
    let(:event) { create(:event, :ended) }
    let(:org) { create(:organization, name: "Lapsed Program") }
    let(:person) { create(:person) }

    before do
      create(:affiliation, organization: org, person: person, title: "Facilitator",
             start_date: 1.year.ago, end_date: 2.days.ago)
      create(:event_registration, event: event, registrant: person, status: "registered")
    end

    it "still counts the program as it was at the time of the event" do
      expect(dashboard.program_status_counts).to eq(new: 1, ongoing: 0, reinstated: 0)
    end

    it "keeps the program in the organization count" do
      expect(dashboard.organization_count).to eq(1)
    end
  end

  describe "unallocated bulk payments" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:bulk_form) { create(:form) }
    let!(:event_form) { create(:event_form, event: event, form: bulk_form, role: "bulk_payment") }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: bulk_form, event: event, role: "bulk_payment") }

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
      other_submission = create(:form_submission, person: payer, form: other_form,
                                event: other_event, role: "bulk_payment")
      create(:payment, person: payer, form_submission: other_submission,
             amount_cents: 9_000, amount_cents_remaining: 9_000)

      expect(dashboard.unallocated_bulk_payment_cents).to eq(0)
    end

    it "ignores submissions on a SHARED bulk form that belong to another event" do
      # Same bulk_form, reused by another event — scoping must key off the
      # submission's own event_id, not the form's event_forms, or this leaks in.
      other_event = create(:event, cost_cents: 10_000)
      create(:event_form, event: other_event, form: bulk_form, role: "bulk_payment")
      other_submission = create(:form_submission, person: payer, form: bulk_form,
                                event: other_event, role: "bulk_payment")
      create(:payment, person: payer, form_submission: other_submission,
             amount_cents: 7_000, amount_cents_remaining: 7_000)

      expect(dashboard.unallocated_bulk_payment_cents).to eq(0)
    end
  end

  describe "unlinked registrations" do
    let(:event) { create(:event) }

    it "counts active registrations with no organization linked" do
      linked = create(:event_registration, event: event, status: "registered")
      create(:event_registration_organization, event_registration: linked)
      create(:event_registration, event: event, status: "registered")
      create(:event_registration, event: event, status: "attended")

      expect(dashboard.unlinked_registration_count).to eq(2)
    end

    it "ignores inactive registrations" do
      create(:event_registration, event: event, status: "cancelled")

      expect(dashboard.unlinked_registration_count).to eq(0)
    end
  end

  describe "attendance stats" do
    let(:event) { create(:event) }

    context "with a mix of attendance outcomes" do
      before do
        create(:event_registration, event: event, registrant: create(:person, first_name: "Aa"), status: "attended")
        create(:event_registration, event: event, registrant: create(:person, first_name: "Ab"), status: "attended")
        create(:event_registration, event: event, registrant: create(:person, first_name: "Ba"), status: "incomplete_attendance")
        create(:event_registration, event: event, registrant: create(:person, first_name: "Ca"), status: "no_show")
        create(:event_registration, event: event, registrant: create(:person, first_name: "Da"), status: "registered")
        create(:event_registration, event: event, registrant: create(:person, first_name: "Ea"), status: "transferred_in")
        create(:event_registration, event: event, registrant: create(:person, first_name: "Fa"), status: "cancelled")
      end

      it "counts each attendance status individually" do
        expect(dashboard.attendance_count_for("attended")).to eq(2)
        expect(dashboard.attendance_count_for("incomplete_attendance")).to eq(1)
        expect(dashboard.attendance_count_for("no_show")).to eq(1)
        expect(dashboard.attendance_count_for("registered")).to eq(1)
        expect(dashboard.attendance_count_for("transferred_in")).to eq(1)
        expect(dashboard.attendance_count_for("cancelled")).to eq(1)
        expect(dashboard.attendance_count_for("transferred_out")).to eq(0)
      end

      it "rates full attendance over every registrant (active + no-shows, excluding cancellations)" do
        expect(dashboard.attendance_recorded?).to be(true)
        expect(dashboard.attendance_outcome_count).to eq(4)
        # 5 active registrants (attended ×2, incomplete, registered, transferred_in)
        # + 1 no-show; the cancellation is excluded.
        expect(dashboard.expected_attendee_count).to eq(6)
        expect(dashboard.attendance_rate).to eq(2.0 / 6)
      end

      it "lists the registrants behind each status" do
        expect(dashboard.attendance_registrants("attended").map(&:first_name)).to eq(%w[ Aa Ab ])
        expect(dashboard.attendance_registrants("no_show").map(&:first_name)).to eq(%w[ Ca ])
        expect(dashboard.attendance_registrants("registered", "transferred_in").map(&:first_name)).to eq(%w[ Da Ea ])
        expect(dashboard.attendance_registrants("cancelled").map(&:first_name)).to eq(%w[ Fa ])
      end
    end

    context "before any outcome is recorded" do
      before do
        create(:event_registration, event: event, status: "registered")
      end

      it "reports nothing recorded and a nil rate" do
        expect(dashboard.attendance_recorded?).to be(false)
        expect(dashboard.attendance_outcome_count).to eq(0)
        expect(dashboard.attendance_rate).to be_nil
        expect(dashboard.attendance_count_for("registered")).to eq(1)
      end
    end
  end

  describe "scholarship funded/unfunded split" do
    let(:event) { create(:event, cost_cents: 50_000) }
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }
    let(:person3) { create(:person) }
    let(:person4) { create(:person) }

    before do
      reg1 = create(:event_registration, event: event, registrant: person1, status: "registered")
      reg2 = create(:event_registration, event: event, registrant: person2, status: "registered")
      reg4 = create(:event_registration, event: event, registrant: person4, status: "registered")

      external = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant))
      create(:allocation, source: external, allocatable: reg1, amount: 4_000)

      comped = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: nil)
      create(:allocation, source: comped, allocatable: reg2, amount: 2_000)

      # A grant the org donated to itself is subsidy, so it counts as UNFUNDED.
      awbw = create(:organization, name: "A Window Between Worlds")
      awbw_award = create(:scholarship, recipient: person4, amount_cents: 1_000, grant: create(:grant, funder: awbw))
      create(:allocation, source: awbw_award, allocatable: reg4, amount: 1_000)

      # A scholarship on a cancelled registration must be ignored everywhere.
      cancelled = create(:event_registration, event: event, registrant: person3, status: "cancelled")
      ignored = create(:scholarship, recipient: person3, amount_cents: 9_000, grant: create(:grant))
      create(:allocation, source: ignored, allocatable: cancelled, amount: 9_000)
    end

    it "counts only externally grant-backed scholarships as funded" do
      expect(dashboard.funded_scholarship_count).to eq(1)
      expect(dashboard.funded_scholarship_cents).to eq(4_000)
    end

    it "counts grant-free and AWBW-donated scholarships as unfunded" do
      expect(dashboard.unfunded_scholarship_count).to eq(2)
      expect(dashboard.unfunded_scholarship_cents).to eq(3_000)
    end

    it "maps funded dollars per recipient, reconciling with the funded total" do
      amounts = dashboard.funded_scholarship_cents_by_recipient
      expect(amounts).to eq(person1.id => 4_000)
      expect(amounts.values.sum).to eq(dashboard.funded_scholarship_cents)
    end

    it "maps unfunded dollars per recipient, reconciling with the unfunded total" do
      amounts = dashboard.unfunded_scholarship_cents_by_recipient
      expect(amounts).to eq(person2.id => 2_000, person4.id => 1_000)
      expect(amounts.values.sum).to eq(dashboard.unfunded_scholarship_cents)
    end

    it "lists funded and unfunded recipients as name-sorted Person records" do
      expect(dashboard.funded_scholarship_recipients).to eq([ person1 ])
      expect(dashboard.unfunded_scholarship_recipients).to match_array([ person2, person4 ])
    end
  end

  describe "program-status classification query count" do
    it "classifies every represented org without a per-org affiliations query" do
      event = create(:event, start_date: Date.current)
      3.times do
        person = create(:person)
        registration = create(:event_registration, event: event, registrant: person, status: "registered")
        org = create(:organization)
        create(:affiliation, organization: org, person: person, title: "Facilitator", start_date: 1.year.ago)
        registration.event_registration_organizations.create!(organization: org)
      end
      dashboard = EventDashboard.new(event)

      affiliation_queries = 0
      counter = ->(_name, _start, _finish, _id, payload) do
        affiliation_queries += 1 if payload[:sql].to_s.include?("FROM `affiliations`")
      end
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        dashboard.program_status_counts
        dashboard.program_status_by_organization
      end

      # Orgs' affiliations are preloaded (one query) plus the batched
      # registrant-affiliation lookup — a small constant, not one-per-org.
      expect(affiliation_queries).to be <= 3
    end
  end
end
