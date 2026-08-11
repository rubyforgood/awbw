require "rails_helper"

RSpec.describe EventChecklist do
  subject(:checklist) { described_class.new(EventDashboard.new(event)) }

  def item(key)
    checklist.items.find { |i| i.key == key }
  end

  describe "structure" do
    let(:event) { create(:event) }

    it "lists items in lifecycle order across the phases" do
      keys = checklist.items.map(&:key)
      expect(keys.first(5)).to eq(%i[ setup_forms setup_callouts setup_publish setup_event_type setup_staff ])
      expect(keys.last(2)).to eq(%i[ review_reports post_event_survey ])
    end

    it "keeps the user's scholarship sub-order (issue -> funders -> agreements -> $0 -> tasks)" do
      scholarship_keys = %i[ issue_scholarships set_scholarship_funders follow_up_agreements
                             fix_zero_scholarships complete_scholarship_tasks ]
      ordered = checklist.items.map(&:key).select { |k| scholarship_keys.include?(k) }
      expect(ordered).to eq(scholarship_keys)
    end

    it "always keeps the post-event survey as an unbuilt placeholder" do
      expect(item(:post_event_survey).kind).to eq(:placeholder)
      expect(item(:post_event_survey)).to be_not_relevant
    end

    it "models review reports as a standing action, not a done-able task" do
      expect(item(:review_reports).kind).to eq(:action)
    end

    it "prefixes every registrant-facing reminder item with 'Send reminder'" do
      reminders = checklist.items.select(&:registrant_task?)
      expect(reminders).to be_present
      expect(reminders.map(&:title)).to all(start_with("Send reminder"))
    end
  end

  describe "before the event, with a registrant" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registrant) { create(:person) }

    before { create(:event_registration, event: event, registrant: registrant, status: "registered") }

    it "flags unpaid registrants as a reminder to-do" do
      fees = item(:collect_registration_fees)
      expect(fees).to be_todo
      expect(fees.count).to eq(1)
      expect(fees.registrants).to include(registrant)
      expect(fees.money_cents).to eq(10_000)
      expect(fees.action_path).to include("preview_reminder", "payment_status=unpaid")
    end

    it "surfaces registrations with no organization via the roster unlinked filter" do
      link = item(:link_organizations)
      expect(link).to be_todo
      expect(link.count).to eq(1)
      expect(link.action_path).to include("org_status=unlinked")
    end

    it "does not surface during/after items before the event happens" do
      %i[ record_attendance reconcile_ce_hours send_completion_certificates review_reports ].each do |key|
        expect(item(key)).to be_not_relevant
      end
    end
  end

  describe "a free event" do
    let(:event) { create(:event, cost_cents: 0) }

    before { create(:event_registration, event: event, registrant: create(:person), status: "registered") }

    it "hides the fee and scholarship items" do
      %i[ collect_registration_fees issue_scholarships set_scholarship_funders
          follow_up_agreements fix_zero_scholarships complete_scholarship_tasks ].each do |key|
        expect(item(key)).to be_not_relevant
      end
    end
  end

  describe "after the event" do
    let(:event) { create(:event, :ended, cost_cents: 10_000) }

    before { create(:event_registration, event: event, registrant: create(:person), status: "registered") }

    it "surfaces recording attendance for registrants with no outcome" do
      attendance = item(:record_attendance)
      expect(attendance).to be_todo
      expect(attendance.count).to eq(1)
      expect(attendance.action_path).to include("attendance_status=registered")
    end

    it "turns reviewing reports into a standing to-do pointing at the stats hub" do
      reports = item(:review_reports)
      expect(reports).to be_todo
      expect(reports.action_path).to eq(Rails.application.routes.url_helpers.reports_events_path)
    end
  end

  describe "staff setup" do
    let(:event) { create(:event) }

    it "is a to-do until event staff are indicated, then done" do
      expect(item(:setup_staff)).to be_todo
      expect(item(:setup_staff).action_path).to eq(Rails.application.routes.url_helpers.staff_event_path(event))
      create(:event_staff, event: event)
      expect(described_class.new(EventDashboard.new(event)).items.find { |i| i.key == :setup_staff }).to be_done
    end
  end

  describe "trainee onboarding" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }
    let!(:reg) { create(:event_registration, event: event, registrant: person, status: "registered") }

    it "is a to-do until every onboarding step is complete, linking to the onboarding page" do
      onboarding = item(:onboard_trainees)
      expect(onboarding).to be_todo
      expect(onboarding.count).to eq(1)
      expect(onboarding.registrants).to eq([ person ])
      expect(onboarding.action_path).to eq(Rails.application.routes.url_helpers.onboarding_event_path(event))

      EventRegistration::CHECKLIST_STEPS.keys.each { |step| reg.checklist_completions.create!(step: step) }
      refreshed = described_class.new(EventDashboard.new(event)).items.find { |i| i.key == :onboard_trainees }
      expect(refreshed).to be_done
    end
  end

  describe "bulk payments" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:form) { create(:form) }
    let(:payer) { create(:person, first_name: "Helena", last_name: "Lopez") }
    let!(:submission) { create(:form_submission, form: form, event: event, person: payer, role: "bulk_payment") }

    before do
      field = create(:form_field, form: form, field_identifier: "payer_organization")
      create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "A Greater Hope")
      create(:payment, form_submission: submission, amount_cents: 7_500, amount_cents_remaining: 7_500)
    end

    it "expands to each submitter with their org and remaining amount" do
      bulk = item(:allocate_bulk_payments)
      expect(bulk).to be_todo
      expect(bulk.count).to eq(1)
      expect(bulk.money_cents).to eq(7_500)
      row = bulk.detail_rows.first
      expect(row.title).to eq(payer.name)
      expect(row.subtitle).to eq("A Greater Hope")
      expect(row.amount_cents).to eq(7_500)
    end
  end

  describe "scholarship agreement reminders" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:recipient) { create(:person) }

    before do
      registration = create(:event_registration, event: event, registrant: recipient, status: "registered")
      scholarship = create(:scholarship, recipient: recipient, amount_cents: 5_000,
                           tasks_completed: true, agreement_signed_at: nil)
      create(:allocation, source: scholarship, allocatable: registration, amount: 5_000)
    end

    it "routes agreement follow-ups to the reminder page via its name filter" do
      agreements = item(:follow_up_agreements)
      expect(agreements).to be_todo
      expect(agreements.action_path).to include("preview_reminder", "name=")
    end
  end

  describe "progress buckets" do
    let(:event) { create(:event, :publicly_visible, published: true) }

    it "counts done vs relevant over trackable items only and resolves the placeholder" do
      expect(checklist.relevant_count).to be_positive
      expect(checklist.done_count).to be <= checklist.relevant_count
      expect(checklist.resolved_items).to include(item(:post_event_survey))
      expect(item(:setup_publish)).to be_done
    end
  end
end
